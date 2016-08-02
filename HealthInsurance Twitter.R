library(dplyr);library(tidytext); library(tidyr); library(randomForest); library(ROCR); library(ggplot2)

###Scrape Twitter using Exporter.py in command line to generate "output_got.csv"###
##Exporter.py derived from https://github.com/Jefferson-Henrique/GetOldTweets-python##
##Command for each company hastag: python Exporter.py --querysearch "[hashtag]" --since 2010-01-01##

###Cleaning tweets###
tweets.cleaning <- read.csv2("output_got.csv", stringsAsFactors = F, quote = "", row.names = NULL)
names(tweets.cleaning) <- names(tweets.cleaning)[-1]
tweets.cleaning$id <- as.character(tweets.cleaning$id)
tweets.cleaning$text <- tolower(tweets.cleaning$text)
tweets.cleaning <- subset(tweets.cleaning, !grepl(pattern="[[:alpha:]]", tweets.cleaning$id) & id != "") #Removes poorly parsed tweets
#Enrich for "opinion" tweets
tweets.cleaning <- subset(tweets.cleaning, !grepl("http", tweets.cleaning$text))
tweets.cleaning <- subset(tweets.cleaning, !grepl("twitter", tweets.cleaning$text))
write.csv(tweets.cleaning,"kaiser.csv",row.names = T)


##Classifying tweets for relevance###
#Manually annotated a subset of tweets for relevance to cosumer opinions on health care
tweets.rel <- read.csv("relevant.csv", stringsAsFactors = F)
tweets.rel$relevant <- as.numeric(!is.na(tweets.rel$trueSentiment))
tweets.rel$id <- as.character(tweets.rel$id)

#Tokenizing
tweetsWords <- tweets.rel %>%
  unnest_tokens(word, text) 
tweetsWords <- tweetsWords %>% 
  count(id, word) %>%
  filter(word != "id") %>%
  mutate(word = make.names(word))
modelWords <- data.frame(word = tweetsWords$word, stringsAsFactors = F)
tweetsWords <- tweetsWords %>%
  spread(word, n, fill = 0) 
tweets.rel <- tweets.rel %>% 
  select(id, relevant) %>%
  inner_join(tweetsWords, by = "id")

#Building relevance RF model
tweets.rel <- tweets.rel[,-1]
training.size <- 0.7
train.index <- sample(1:nrow(tweets.rel), round(training.size*nrow(tweets.rel), 0))
test.index <- setdiff(1:nrow(tweets.rel), train.index)
train <- tweets.rel[train.index, ]
test <- tweets.rel[test.index, ]

relForest <- randomForest(factor(relevant) ~ ., data = train, importance = TRUE, ntree = 100)
relPrediction <- predict(relForest, test)
relPred <- prediction(as.numeric(as.character(relPrediction)), test$relevant)
relPerf <- performance(relPred,"tpr","fpr")
plot(relPerf)
abline(0,1)
performance(relPred, measure = "auc")@y.values

###Compiling all provide tweets###
tweets <- cbind(read.csv("kaiser2.csv", stringsAsFactors = F), data.frame("org" = "kaiser"))
tweets <- rbind(tweets, cbind(read.csv("aetna2.csv", stringsAsFactors = F), data.frame("org" = "aetna")))
tweets <- rbind(tweets, cbind(read.csv("cigna.csv", stringsAsFactors = F), data.frame("org" = "cigna")))
tweets <- rbind(tweets, cbind(read.csv("bluecross.csv", stringsAsFactors = F), data.frame("org" = "bluecross")))

tweets$id <- factor(1:nrow(tweets))

###Applying relevance classification model
tweetsWords <- tweets %>%
  unnest_tokens(word, text)
tweetsWords <- tweetsWords %>% 
  count(id, word) %>%
  semi_join(modelWords, by = "word") %>%
  filter(word != "id") %>%
  spread(word, n, fill = 0)
tweetsRelSort <- tweets %>% 
  select(id) %>%
  inner_join(tweetsWords, by = "id")
#Adding the model words not in the actual data 
remainingWords <- setdiff(modelWords$word, names(tweetsRelSort))
remainingWords.df <- as.data.frame(matrix(0, ncol = length(remainingWords), nrow = nrow(tweetsRelSort)))
names(remainingWords.df) <- remainingWords
tweetsRelSort <- cbind(tweetsRelSort, remainingWords.df)
#Predicting relevance with model
relPrediction <- predict(relForest, tweetsRelSort)
#Sorting for only relevant tweets
tweets <- tweets[relPrediction == 1, ]

# write.csv(tweets, "testTweets.csv", row.names = F)


###Building sentiment-classifier-RF model###
tweetsModel <- read.csv("testTweets.csv", stringsAsFactors = F)
tweetsModel <- subset(tweetsModel, !is.na(tweetsModel$trueSentiment))

#Downsampling b/c of class imbalance
set.seed(1)
tweetsModel <- rbind(subset(tweetsModel, trueSentiment == 1),
                     subset(tweetsModel, trueSentiment == 0)[sample(1:nrow(subset(tweetsModel, trueSentiment == 0)), nrow(subset(tweetsModel, trueSentiment == 1))),]
)


#Tokenizing
tweetsWords <- tweetsModel %>%
  unnest_tokens(word, text) %>%
  anti_join(stop_words)
tweetsWords <- tweetsWords %>% 
  count(id, word) %>%
  # bind_tf_idf(word, id, n) %>%
  # filter(word != "id" & tf_idf > 0) %>%
  filter(word != "id") %>%
  mutate(word = make.names(word))
modelWords <- data.frame(word = tweetsWords$word, stringsAsFactors = F)
tweetsWords <- tweetsWords %>%
  # select(-tf, -idf, -tf_idf) %>%
  spread(word, n, fill = 0) 
tweetsSent <- tweetsModel %>% 
  select(id, trueSentiment) %>%
  inner_join(tweetsWords, by = "id")
tweetsSent <- tweetsSent[,-1]

#Building model
set.seed(1)
training.size <- 0.7
train.index <- sample(1:nrow(tweetsSent), round(training.size*nrow(tweetsSent), 0))
test.index <- setdiff(1:nrow(tweetsSent), train.index)
train <- tweetsSent[train.index, ]
test <- tweetsSent[test.index, ]
sentForest <- randomForest(factor(trueSentiment) ~ ., data = train, importance = TRUE, ntree = 1000)
varImpPlot(sentForest)
sentPrediction <- predict(sentForest, test)
sentPred <- prediction(as.numeric(as.character(sentPrediction)), test$trueSentiment)
sentPerf <- performance(sentPred,"tpr","fpr")
auc <- performance(sentPred, measure = "auc")@y.values[[1]]
plot(sentPerf, main = paste("Downsampled sentiment classifier, auc =", round(auc, 5)))


###Applying relevance classification model###
# tweets$id <- 1:length(tweets$id)
tweets$id <- droplevels(tweets$id)
tweetsWords <- tweets %>%
  unnest_tokens(word, text)
tweetsWords <- tweetsWords %>% 
  count(id, word) %>%
  semi_join(modelWords, by = "word") %>%
  filter(word != "id") %>%
  spread(word, n, fill = 0, drop = F)
tweetsSentClass <- tweets %>% 
  select(id) %>%
  inner_join(tweetsWords, by = "id")
#Adding the model words not in the actual data 
remainingWords <- setdiff(modelWords$word, names(tweetsSentClass))
remainingWords.df <- as.data.frame(matrix(0, ncol = length(remainingWords), nrow = nrow(tweetsSentClass)))
names(remainingWords.df) <- remainingWords
tweetsSentClass <- cbind(tweetsSentClass, remainingWords.df)
#Predicting relevance with model
sentPrediction <- predict(sentForest, tweetsSentClass)
tweets$predSentiment <- sentPrediction == 1

###Summarizing classified data for plots
#Total summary plot
summary <- tweets %>%
  count(org, predSentiment) %>%
  spread(predSentiment, n, fill = 0)
names(summary) <- c("org", "neg", "pos")
summary <- summary %>%
  mutate(relativePos = pos/neg) %>%
  ungroup() %>%
  mutate(standPos = log(relativePos/(sum(pos)/sum(neg)))) %>%
  arrange(desc(relativePos))
ggplot(tweets, aes(x = org, fill= predSentiment)) + geom_bar(position = "fill") + theme(axis.text.x = element_text(angle = 45))
ggplot(summary, aes(x = factor(org, levels = summary$org), y = standPos)) + geom_bar(stat="identity")

#Plot by year
date <- strptime(tweets$date, format = "%m/%d/%Y %H:%M")
tweets$month <- as.character(format(date, format = "%Y-%m"))
tweets$year <- as.character(format(date, format = "%Y"))
summary <- tweets %>%
  mutate(year = as.numeric(year)) %>%
  select(-date) %>%
  group_by(year, org) %>%
  summarise(pos = sum(predSentiment == TRUE), neg = sum(predSentiment == FALSE)) %>%
  mutate(relativePos = pos/neg) %>%
  group_by(year) %>%
  mutate(standPos = relativePos- (sum(pos)/sum(neg))) %>%
  ungroup() %>%
  arrange(year)
ggplot(summary, aes(x = as.numeric(year), y = relativePos, group= org, color = org)) + 
  geom_path(stat="identity", size = 1) +
  theme_classic() +
  scale_color_brewer(palette = "Set1")

write.csv(summary, "summary.csv", row.names = F)
###Negative tweets per member###
#https://share.kaiserpermanente.org/article/fast-facts-about-kaiser-permanente/
#https://www.aetna.com/about-us/aetna-facts-and-subsidiaries/aetna-facts.html
#http://www.cigna.com/about-us/company-profile/cigna-fact-sheet
#http://www.bcbs.com/about-the-association/?referrer=https://www.google.com/

# summary <- read.csv("summary.csv")
enrolled <- read.csv("memberNumbers.csv", skip = 1)
enrolled <- enrolled[,-6]
enrolled <- enrolled %>% gather(key = year, value = members)
names(enrolled) <- c("year", "org", "members")


summary <- summary %>%
  inner_join(enrolled) %>%
  mutate(neg.per.mill = neg/members) %>%
  arrange(desc(neg.per.mill)) %>%
  mutate(org = factor(org, org))

write.csv(summary, "summary2.csv", row.names = F)

summary %>%
  ggplot(aes(x = org, y = neg.per.mill)) +
  geom_bar(stat = "identity") +
  theme_classic() +
  facet_wrap(~ year)


#Word cloud
library(wordcloud)
tweetsSplit <- split(tweetsWords, paste0(tweets$org, tweets$predSentiment))
cloudList <- function(x){
  exclude <- c("kaiserpermanente", "aetna", "cigna", "bluecrossblueshield", "healthcare", "insurance", "health", "kaiser", "company", "medical")
  d <- x %>% gather(word, rate, -id) %>% group_by(word) %>% summarise(freq = sum(rate)) %>% filter(!(word %in% exclude))
  d
}
tweetsCloud <- lapply(tweetsSplit, cloudList)
for (i in 1:length(tweetsCloud)){
  wordcloud(tweetsCloud[[i]]$word,tweetsCloud[[i]]$freq)
  par(new = T)
  plot(1, type = "n", axes = F, xlab = "", ylab = "", main = names(tweetsCloud)[i])
}


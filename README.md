# Analyzing Health Insurance Customer Satisfaction via Twitter

## General strategy
1) Search for tweets based on health care provider hashtags using [python-based scraping tool](https://github.com/Jefferson-Henrique/GetOldTweets-python) that circumvents ~7 day limit of traditional Twitter API

2) Manually annotate subset of tweets as relevant (i.e. express customer satisfaction opinion) and as having either positive or negative sentiment

3) Train and apply a random forest classifier to classify full tweet data set by relevance

4) Train and apply a random forest classifier to classify relevant tweets as expressing either positive or negative sentiment

5) Analytics of tweet sentiment

## Visuals

[Negative tweets per million members](https://fathomless-plains-81085.herokuapp.com/?ticker=2012&)

[Annual proportion of positive tweets](https://radiant-temple-57731.herokuapp.com/)

[Negative tweet wordcloud for Kaiser Permanente](https://github.com/BenSolomon/HealthInsuranceTweets/blob/master/Kaiser%20negative%20word%20cloud.jpeg)

[Negative tweet wordcloud for Aetna](https://github.com/BenSolomon/HealthInsuranceTweets/blob/master/Aetna%20negative%20cloud.jpeg)

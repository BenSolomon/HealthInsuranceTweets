from spyre import server

import os
import pandas as pd
import numpy as np
from matplotlib import pyplot as plt

class NegativeTweets(server.App):
    title = "Annual Proportion of Positive Tweets"

    inputs = [{     "type":'checkboxgroup',
                    "label": 'Insurance Organization',
                    "options" : [ {"label": "Aetna", "value":"aetna", "checked":True},
                                  {"label": "Blue Cross Blue Shield", "value":"bluecross"},
                                  {"label": "Cigna", "value":"cigna"},
                                  {"label": "Kaiser Permanente", "value":"kaiser"}],
                    "key": 'ticker',
                    "action_id": "update_data"}]

    controls = [{   "type" : "hidden",
                    "id" : "update_data"}]


    outputs = [{ "type" : "plot",
                    "id" : "plot",
                    "control_id" : "update_data",
                    "tab" : "Plot"}]

    def getPlot(self, params):
        df = pd.read_csv("summary.csv")
        df = df[df['year'] > 2009]
        index = []
        for i in df['org']: index.append(i in params['ticker'])
        df = df[index]
        df = df.pivot(index='year', columns = 'org', values='relativePos')
        df.index.name = None
        plt_obj = df.plot()
        plt_obj.get_xaxis().get_major_formatter().set_useOffset(False)
        plt_obj.set_xlabel("Year")
        plt_obj.set_ylabel("Proportion of Positive Tweets")
        plt_obj.legend(loc = 0, title = "Health Insurance \n Organization")
        plt_obj.set_title("")
        fig = plt_obj.get_figure()
        return fig



if __name__ == '__main__':
    app = NegativeTweets()
    app.launch(host='0.0.0.0', port=int(os.environ.get('PORT', '5000')))

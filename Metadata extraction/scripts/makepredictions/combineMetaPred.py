#python
import json
import pandas as pd
import numpy as np
import csv
import json
import sys
import os

def detect_sep(filepath):
    '''
    Simple function to detect which delimiter is used in inputfile.
    filepath = path to file
    returns: delimiter used in file
    '''
    sniffer = csv.Sniffer()
    with open(filepath, 'r') as c:
        return(sniffer.sniff(c.readlines()[0]).delimiter)

def load_csv(filepath,
             label_features=[]):
    '''
    Basic function to load the dataset from an input file. It assumes it has been unaltered.
    Will drop the columns classified as "label" by the user.
    '''         
    data = pd.read_csv(filepath, sep=detect_sep(filepath))
    data = data.drop(label_features, axis=1)
    return(data)


path_inputdata = sys.argv[1] #.meta
path_predictions = sys.argv[2] #.json
path_output = sys.argv[3]

filename=os.path.basename(path_inputdata)

# load data using Python JSON module
with open(path_predictions,'r') as f:
    preds = json.loads(f.read())
# Flatten data
df_nested_list = pd.json_normalize(preds, record_path =['predictions'])

df_nested_list[['NOR','VAR']] = pd.DataFrame(df_nested_list.scores.tolist(), index= df_nested_list.index)
df_nested_list['predictions'] = df_nested_list['NOR'] > df_nested_list['VAR']

# Load data
data = load_csv(path_inputdata, [])
data = data.fillna(0) # Simple imputation

data['predictions']=df_nested_list['predictions'].replace({True: 'NOR', False: 'VAR'})
data.to_csv(path_output+filename+'.pred', index=False)


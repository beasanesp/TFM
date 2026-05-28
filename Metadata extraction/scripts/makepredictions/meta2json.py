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
    
# parsing the command line arguments    
path_inputdata = sys.argv[1]
path_output = sys.argv[2]
# Get the filename
filename=os.path.basename(path_inputdata)

# Load data
data = load_csv(path_inputdata, [])
data = data.fillna(0) # Simple imputation
#data.columns = data.columns.str.replace(r".", "_")

data = data.astype(str) # Convert all values to string (required by model for some reason)

data_json = json.loads(data.to_json(orient='table', index=False)) # Convert to json
wanted = json.loads('{"instances":[]}') # base json for predictions
# For - loop to add each row to the observation
for i in range(len(data_json['data'])):
    wanted['instances'].append(data_json['data'][i])
# Save
outputfile = path_output+filename+'.json'
with open(outputfile, 'w') as outfile:
    json.dump(wanted, outfile)




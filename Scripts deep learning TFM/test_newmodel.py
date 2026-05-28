
#Import packages
from pytorch_tabnet.tab_model import TabNetClassifier
import torch
from torch.optim import Adam
from sklearn.preprocessing import LabelEncoder
from sklearn.metrics import classification_report, confusion_matrix, ConfusionMatrixDisplay
import pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import joblib


# 1. Define the model
model_Tabnet = TabNetClassifier(    
    optimizer_fn=Adam,
    optimizer_params=dict(lr=0.01))

#Import the trained model
model_Tabnet.load_model("final_results/test1-train_batch1/model_batch1.zip")

#2. Import the new dataset
df= pd.read_csv("twist-data/all23456789940715_1_recaled.meta", sep="\t")

#3. Preprocess the data
feature_cols = ["doc", "doc.sd", "log", "gc.perc", "length", "repeatmasked"]
target_col = 'variant'

df[feature_cols] = df[feature_cols].astype(float)
df[target_col] = df[target_col].replace({'DUP': 'VAR', 'DEL': 'VAR'})

print("Valores nulos antes:", df[target_col].isna().sum())
df = df.dropna(subset=[target_col])
print("Filas después de eliminar nulos:", df.shape)


#4. Reuse the trained model's label encoder
le = joblib.load('final_results/test2-merged/label_encoder.pkl')
df[target_col] = le.transform(df[target_col])
print("Clases codificadas:", le.classes_)

X_new = df[feature_cols]
y_new = df[target_col]

#5. Generate report and confusion matrix

predictions = model_Tabnet.predict(X_new.values)

print(classification_report(y_new, predictions, target_names=le.classes_))
report_dict = classification_report(y_new, predictions, target_names=le.classes_,output_dict=True)
report_df = pd.DataFrame(report_dict).transpose()
report_df.to_csv("final_results/test3-finetunedreport-NG_sample_DECON.csv", index=True)

#Generar confusion matrix
cm = confusion_matrix(y_new,predictions)
disp = ConfusionMatrixDisplay(confusion_matrix=cm, display_labels=le.classes_)
disp.plot(cmap=plt.cm.Blues, values_format='d')
plt.title("Confusion Matrix")
plt.tight_layout()
plt.savefig("final_results/test3-finetunedconfusion-matrix-NG_sample_DECON.png")
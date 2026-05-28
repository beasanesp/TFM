
#Import packages
from pytorch_tabnet.tab_model import TabNetClassifier
from sklearn.preprocessing import StandardScaler, LabelEncoder
import pandas as pd
import numpy as np
from sklearn.model_selection import train_test_split
from sklearn.metrics import classification_report, confusion_matrix, ConfusionMatrixDisplay
import joblib
from torch.optim import Adam
import torch
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

# 1. Define new dataset
df_new = pd.read_csv("ICR96_data/17332_DECoN_cleaned.meta", sep="\t")

feature_cols = ["doc", "doc.sd", "log", "gc.perc", "length", "repeatmasked"]
target_col = "variant"

df_new[feature_cols] = df_new[feature_cols].astype(float)
df_new[target_col] = df_new[target_col].replace({'DUP': 'VAR', 'DEL': 'VAR'})

# 2.Reuse anterior model's label encoder
le = joblib.load('final_results/test2-merged/label_encoder.pkl')
df_new[target_col] = le.transform(df_new[target_col])

print("¿Hay NaNs en features?:", df_new[feature_cols].isnull().any())
print("¿Hay NaNs en target?:", df_new[target_col].isnull().any())

X_new =df_new[feature_cols].values
y_new = df_new[target_col].values

# 4. Split the data
X_train_new, X_valid_new, y_train_new, y_valid_new = train_test_split(
    X_new, y_new, test_size=0.2, random_state=42
)


# 5. Retrain the model in new dataset with low learning rate

clf = TabNetClassifier(
    optimizer_fn=Adam,
    optimizer_params=dict(lr=0.0001)
)

#Import the trained model
clf.load_model('final_results/test2-merged/tabnet_model_merged.zip')

clf.fit(
    X_train=X_train_new,
    y_train=y_train_new,
    eval_set=[(X_train_new, y_train_new), (X_valid_new, y_valid_new)],
    eval_name=["train", "valid"],
    eval_metric=["accuracy"],
    max_epochs=50,
    patience=10,
    batch_size=256,
    virtual_batch_size=128,
    from_unsupervised=None,
)

predictions = clf.predict(X_new)

print(classification_report(y_new, predictions, target_names=le.classes_))
report_dict = classification_report(y_new, predictions, target_names=le.classes_,output_dict=True)
report_df = pd.DataFrame(report_dict).transpose()
report_df.to_csv("TFM/Tests in samples/ICR96_Decon-finetuned.csv", index=True)

# 7. Generate confusion matrix
cm = confusion_matrix(y_new,predictions)
disp = ConfusionMatrixDisplay(confusion_matrix=cm, display_labels=le.classes_)
disp.plot(cmap=plt.cm.Blues, values_format='d')
plt.title("Confusion Matrix")
plt.tight_layout()
plt.savefig("TFM/Tests in samples/ICR96_Decon-finetuned.png") #For saving in png

# 8. Save the model
clf.save_model("TFM/Tests in samples/ICR96_decon-finetuned")



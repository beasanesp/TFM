
#Import of packages
import pandas as pd
import numpy as np
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import LabelEncoder
from sklearn.metrics import confusion_matrix, ConfusionMatrixDisplay, classification_report
from pytorch_tabnet.tab_model import TabNetClassifier
from torch.optim import Adam
import torch
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import joblib


# 1. Data preprocessing

df = pd.read_csv("ICR96_data/log_17332.meta", sep="\t")

feature_cols = ["doc", "doc.sd", "log", "gc.perc", "length", "repeatmasked"]
target_col = 'variant'

df[feature_cols] = df[feature_cols].astype(float)
df[target_col] = df[target_col].replace({'DUP': 'VAR', 'DEL': 'VAR'})

# 2. Encode target
le = LabelEncoder()
df[target_col] = le.fit_transform(df[target_col])
print("Clases codificadas:", le.classes_)
#joblib.dump(le, 'final_results/test7-decon-NG-model/label_encoder_decon.pkl')

print("¿Hay NaNs en features?:", df[feature_cols].isnull().any())
print("¿Hay NaNs en target?:", df[target_col].isnull().any())

# 3. Split train and test
X = df[feature_cols].values
y = df[target_col].values
X_temp, X_test, y_temp, y_test = train_test_split(X, y, test_size=0.2, random_state=42)
X_train, X_valid, y_train, y_valid = train_test_split(
    X_temp, y_temp, test_size=0.2, random_state=42)

# 4. Selection of model and optimizer 
clf = TabNetClassifier(
    optimizer_fn=Adam,
    optimizer_params=dict(lr=0.01))

# 5. Train the model
clf.fit(
    X_train=X_train,
    y_train=y_train,
    eval_set=[(X_train, y_train), (X_valid, y_valid)],
    eval_name=['train', 'valid'],
    eval_metric=['accuracy'],
    max_epochs=50,
    patience=10,
    batch_size=2000,
    #virtual_batch_size= 128
    
)


# 6. Evaluation

#Classification report
y_pred = clf.predict(X_test)
print(classification_report(y_test, y_pred, target_names=le.classes_))
report_dict = classification_report(y_test, y_pred, target_names=le.classes_,output_dict=True)
report_df = pd.DataFrame(report_dict).transpose()
#report_df.to_csv("real_tests/test1-train_model_real_batch1/report-batch1.csv", index=True) #For saving csv


#Confusión matrix
cm = confusion_matrix(y_test, y_pred)
disp = ConfusionMatrixDisplay(confusion_matrix=cm, display_labels=le.classes_)
disp.plot(cmap=plt.cm.Blues, values_format='d')
plt.title("Confusion Matrix - Mejor Modelo")
#plt.savefig("real_tests/test1-train_model_real_batch1/confusion_matrix-batch1.png") #For saving png

#Loss graphic
losses = clf.history['loss']
plt.figure(figsize=(8, 5))
plt.plot(range(1, len(losses) + 1), losses, marker='o', label='Validation Loss')
plt.xlabel("Epoch")
plt.ylabel("Loss")
plt.title("Validation Loss over Epochs")
plt.grid(True)
plt.legend()
plt.tight_layout()
#plt.savefig("real_tests/test1-train_model_real_batch1/loss-batch1.png") #For saving png

# 7. Feature importance
importances = clf.feature_importances_
feature_names = feature_cols

# Print feature importance
importance_df = pd.DataFrame({
    'Feature': feature_names,
    'Importance': importances
}).sort_values(by='Importance', ascending=False)

print("\n Feature importance :")
print(importance_df)


#Exportation the graphic
plt.figure(figsize=(6, 4))
plt.barh(importance_df['Feature'], importance_df['Importance'], color='skyblue')
plt.xlabel("Importance")
plt.title("Feature Importance (TabNet)")
plt.gca().invert_yaxis()  
plt.tight_layout()
#plt.savefig("real_tests/test1-train_model_real_batch1/feature_importance-batch1.png") #For saving png

#8. Save the model as .zip
print("Saving model...")
#clf.save_model('real_tests/test1-train_model_real_batch1/model_batch1')


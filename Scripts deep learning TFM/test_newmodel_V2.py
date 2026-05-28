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
import os
import numpy as np


# Inicializar modelo
model_Tabnet = TabNetClassifier(
    optimizer_fn=Adam,
    optimizer_params=dict(lr=0.01)
)

# Cargar modelo entrenado
model_Tabnet.load_model("final_results/test2-merged/tabnet_model_merged.zip")

# Cargar datos
df = pd.read_csv("real_tests/ICR96_real.meta", sep="\t",dtype={"start":str,"end":str})
feature_cols = ["doc", "doc.sd", "log", "gc.perc", "length", "repeatmasked"]
target_col = 'variant'

# Preprocesamiento
df[feature_cols] = df[feature_cols].astype(float)
df[target_col] = df[target_col].replace({'DUP': 'VAR', 'DEL': 'VAR'})
df = df.dropna(subset=[target_col])

# Codificar clases
le = joblib.load('final_results/test2-merged/label_encoder.pkl')
df[target_col] = le.transform(df[target_col])

# Crear columna de región
df['region'] = df['start'].astype(str) + '-' + df['end'].astype(str)

summary_rows = []
labels = list(range(len(le.classes_)))  # Ej: [0, 1]

grouped = df.groupby(['start', 'end'])


for (start, end), group in grouped:
    region_name = f"{start}-{end}"
    print(f"\n--- Región: {region_name} ---")
    
    if group[feature_cols].isnull().any().any() or group[target_col].isnull().any():
        print(f"Saltando región {region_name} por valores nulos.")
        continue

    X_region = group[feature_cols]
    y_region = group[target_col]

    # Probabilidades y predicción global de la región
    probas = model_Tabnet.predict_proba(X_region.values)
    mean_proba = probas.mean(axis=0)
    final_pred = np.argmax(mean_proba)
    pred_class = le.classes_[final_pred]
    
    # Conteo real de clases en la región
    class_counts = y_region.value_counts().to_dict()
    class_counts_named = {le.classes_[k]: v for k, v in class_counts.items()}

    # Construir fila del resumen
    row = {
        "region": region_name,
        "start": start,
        "end": end,
        "predicted_class": pred_class,
        "log": group["log"].mean(),
    }

    # Añadir probabilidades
    for i, cls in enumerate(le.classes_):
        row[f"proba_{cls}"] = mean_proba[i]

    # Añadir conteo real por clase
    for cls in le.classes_:
        row[f"true_count_{cls}"] = class_counts_named.get(cls, 0)

    summary_rows.append(row)

# Guardar resumen global
summary_df = pd.DataFrame(summary_rows)
summary_df.to_csv("real_tests/test4-con_sin_unders/ICR96/summary_prediction_by_region_logdataset_real.csv", index=False)
print("\n✅ Resumen guardado en: summary_prediction_by_region.csv")
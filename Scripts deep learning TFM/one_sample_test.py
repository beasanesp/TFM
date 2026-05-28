import pandas as pd
import numpy as np
import joblib
import argparse
from pytorch_tabnet.tab_model import TabNetClassifier

# ---------------------------
# CONFIGURACIÓN
# ---------------------------

MODEL_PATH = "final_results/test2-merged/tabnet_model_merged.zip"
ENCODER_PATH= "final_results/test2-merged/label_encoder.pkl"
FEATURE_COLUMNS = ["doc", "doc.sd", "log", "gc.perc", "length", "repeatmasked"]
START_COLUMN = "start"
END_COLUMN = "end"

# ---------------------------
# ARGUMENTOS
# ---------------------------

parser = argparse.ArgumentParser()
parser.add_argument("--start", type=int, required=True, help="Valor de inicio de la región")
parser.add_argument("--end", type=int, required=True, help="Valor de fin de la región")
args = parser.parse_args()

# ---------------------------
# CARGAR EL MODELO
# ---------------------------

model = TabNetClassifier()
model.load_model(MODEL_PATH)

le = joblib.load(ENCODER_PATH)
LABEL_MAPPING = {i: label for i, label in enumerate(le.classes_)}

# ---------------------------
# CARGAR DATASET
# ---------------------------

df = pd.read_csv("twist-data/23456789940715_1_unders.meta", sep="\t")

# Verificar que existen las columnas necesarias
if START_COLUMN not in df.columns or END_COLUMN not in df.columns:
    raise ValueError("El archivo debe contener las columnas 'start' y 'end'.")

# Filtrar por la región exacta (start y end)
df_region = df[(df[START_COLUMN] == args.start) & (df[END_COLUMN] == args.end)].copy()

if df_region.empty:
    raise ValueError(f"No se encontró ninguna entrada con start={args.start} y end={args.end}")

# Asegurar tipos correctos
df_region[FEATURE_COLUMNS] = df_region[FEATURE_COLUMNS].astype(float)

# Convertir a array para el modelo
X = df_region[FEATURE_COLUMNS].values

# ---------------------------
# PREDICCIÓN AGREGADA
# ---------------------------

probas = model.predict_proba(X)
mean_proba = probas.mean(axis=0)
final_pred = np.argmax(mean_proba)

class_counts = df_region["variant"].value_counts()

# ---------------------------
# RESULTADO FINAL
# ---------------------------

region_length = args.end - args.start
print("=== GLOBAL PREDICTION OF THE REGION ===")
print(f"Start: {args.start}, End: {args.end} (Length: {region_length})")
print(f"Predict Class: {LABEL_MAPPING[final_pred]}")
print(f"Probabilities: {dict(zip(le.classes_, mean_proba))}")
print("\n=== ACTUAL CLASS COUNT ===")
for cls, count in class_counts.items():
    print(f"{cls}: {count} ")


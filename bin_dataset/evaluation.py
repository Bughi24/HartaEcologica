import tensorflow as tf
from tensorflow.keras.preprocessing.image import ImageDataGenerator
from sklearn.metrics import classification_report, confusion_matrix
import numpy as np
import os

# --- CONFIGURARE ---
IMG_SIZE = 224
BATCH_SIZE = 32
DATASET_DIR = 'bin_dataset/dataset' # Asigură-te că calea este corectă
MODEL_PATH = 'model_intermediar.keras'

# 1. ÎNCĂRCARE MODEL
if not os.path.exists(MODEL_PATH):
    print(f"Eroare: Nu am găsit fișierul {MODEL_PATH}!")
    exit()

print("Se încarcă modelul...")
model = tf.keras.models.load_model(MODEL_PATH)

# 2. PREGĂTIREA DATELOR DE TEST (VALIDARE)
# Trebuie să fie identice cu cele din antrenare (split 20%)
test_datagen = ImageDataGenerator(rescale=1./255, validation_split=0.2)

test_generator = test_datagen.flow_from_directory(
    DATASET_DIR,
    target_size=(IMG_SIZE, IMG_SIZE),
    batch_size=BATCH_SIZE,
    class_mode='binary',
    subset='validation', # Folosim doar bucata de test
    shuffle=False        # IMPORTANT: Altfel etichetele nu se vor potrivi cu imaginile
)

# 3. GENEREAZĂ PREDICȚII
print("Se analizează imaginile de validare...")
predictions = model.predict(test_generator)

# Convertim probabilitățile (0.0 - 1.0) în clase binare (0 sau 1)
# Pragul standard este 0.5
y_pred = (predictions > 0.5).astype(int).flatten()

# Luăm etichetele reale din folder
y_true = test_generator.classes

# Extragem numele claselor detectate
target_names = list(test_generator.class_indices.keys())

# 4. AFIȘARE REZULTATE
print("\n" + "="*30)
print("   CLASSIFICATION REPORT")
print("="*30)
print(classification_report(y_true, y_pred, target_names=target_names))

print("\n" + "="*30)
print("   CONFUSION MATRIX")
print("="*30)
matrix = confusion_matrix(y_true, y_pred)
print(matrix)

# Explicație rapidă a matricii de confuzie
print(f"\nInterpretare pentru {target_names}:")
print(f" - [0,0]: Corect detectate ca '{target_names[0]}'")
print(f" - [1,1]: Corect detectate ca '{target_names[1]}'")
print(f" - [0,1] și [1,0]: Erori de clasificare")
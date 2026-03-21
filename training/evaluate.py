import tensorflow as tf
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from sklearn.metrics import classification_report, confusion_matrix

# 1. SETĂRI ȘI PARAMETRI (Trebuie să fie aceiași ca la antrenare)
IMG_SIZE = 224
BATCH_SIZE = 32

# 2. ÎNCĂRCARE DATASET DE VALIDARE
# Folosim aceleași setări pentru a extrage exact aceleași imagini de test
val_ds = tf.keras.utils.image_dataset_from_directory(
    'training/garbage_classification',
    validation_split=0.2,
    subset="validation",
    seed=123,
    image_size=(IMG_SIZE, IMG_SIZE),
    batch_size=BATCH_SIZE,
    label_mode='categorical'
)

class_names = val_ds.class_names

# 3. ÎNCĂRCARE MODEL SALVAT
print("Se încarcă modelul...")
model = tf.keras.models.load_model('final_waste_model.keras')

print("Se generează predicțiile (acest proces poate dura câteva minute)...")

# 4. COLECTARE PREDICȚII ȘI ETICHETE REALE
y_true = []
y_pred = []

# Iterăm prin dataset-ul de validare
for images, labels in val_ds:
    # Etichete reale
    y_true.extend(np.argmax(labels.numpy(), axis=1))
    
    # Predicții model
    preds = model.predict(images, verbose=0)
    y_pred.extend(np.argmax(preds, axis=1))

# 5. GENERARE CLASSIFICATION REPORT (Text pentru Word)
report = classification_report(y_true, y_pred, target_names=class_names)
print("\n--- CLASSIFICATION REPORT ---")
print(report)

# Salvare raport în fișier text
with open("evaluation_results.txt", "w", encoding="utf-8") as f:
    f.write("=== CLASSIFICATION REPORT ===\n")
    f.write(report)

# 6. GENERARE MATRICE DE CONFUZIE (Vizuallizare pentru Prezentare)
cm = confusion_matrix(y_true, y_pred)
plt.figure(figsize=(12, 10))
sns.heatmap(cm, annot=True, fmt='d', cmap='Greens', 
            xticklabels=class_names, yticklabels=class_names)
plt.xlabel('Predicție Model')
plt.ylabel('Etichetă Reală')
plt.title('Matricea de Confuzie - Clasificare Deșeuri')

# Salvare grafic ca imagine
plt.savefig('confusion_matrix.png')
print("\nSucces! Raportul text și Matricea de Confuzie au fost salvate.")
plt.show()
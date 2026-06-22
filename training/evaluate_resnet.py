import tensorflow as tf
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from sklearn.metrics import classification_report, confusion_matrix

# SETĂRI 
IMG_SIZE = 224
BATCH_SIZE = 32

# ÎNCĂRCARE DATASET DE VALIDARE
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

# ÎNCĂRCARE MODEL RESNET50
print("Se încarcă modelul ResNet50...")
model = tf.keras.models.load_model('resnet50_waste_model.keras')

print("Se generează predicțiile pe setul de validare...")

# COLECTARE DATE PENTRU EVALUARE
y_true = []
y_pred = []

# Iterăm prin dataset
for images, labels in val_ds:
    # Salvăm etichetele reale
    y_true.extend(np.argmax(labels.numpy(), axis=1))
    
    # Generăm predicțiile
    preds = model.predict(images, verbose=0)
    y_pred.extend(np.argmax(preds, axis=1))

# GENERARE CLASSIFICATION REPORT (Metrici pentru tabele)
report = classification_report(y_true, y_pred, target_names=class_names)
print("\n=== RESNET50 CLASSIFICATION REPORT ===")
print(report)

# Salvăm raportul într-un fișier text pentru referință ulterioară
with open("resnet50_report.txt", "w", encoding="utf-8") as f:
    f.write(report)

# GENERARE MATRICE DE CONFUZIE (Grafic pentru lucrare)
cm = confusion_matrix(y_true, y_pred)
plt.figure(figsize=(12, 10))
sns.heatmap(cm, annot=True, fmt='d', cmap='Blues', 
            xticklabels=class_names, yticklabels=class_names)
plt.xlabel('Predicție Model (ResNet50)')
plt.ylabel('Etichetă Reală (Ground Truth)')
plt.title('Matricea de Confuzie - ResNet50 Waste Classification')

# Salvare grafic
plt.savefig('resnet50_confusion_matrix.png')
print("\nSucces! Raportul și Matricea de Confuzie au fost salvate.")
plt.show()
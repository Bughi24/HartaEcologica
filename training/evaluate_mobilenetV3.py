import tensorflow as tf
from tensorflow.keras.preprocessing.image import ImageDataGenerator
from sklearn.metrics import classification_report, confusion_matrix
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns

# Încărcăm noul model MobileNetV3
model_path = 'mobilenet_v3_garbage.keras' 
print(f"Încărcăm modelul: {model_path}...")
model = tf.keras.models.load_model(model_path)

img_size = 224 # Dimensiunea corectă pentru MobileNetV3
batch_size = 16

# 2. Generatorul de date 
datagen = ImageDataGenerator(validation_split=0.2)

# Încărcăm strict datele de validare
print("Încărcăm datele de validare...")
val_data = datagen.flow_from_directory(
    'training/garbage_classification',
    target_size=(img_size, img_size),
    batch_size=batch_size,
    class_mode='categorical',
    subset='validation',
    shuffle=False 
)

# Executăm predicțiile pe tot setul de validare
print("Se execută inferența pe setul de validare... Te rog așteaptă.")
preds = model.predict(val_data)
y_pred = np.argmax(preds, axis=1) # Alegem clasa cu probabilitatea maximă
y_true = val_data.classes         # Etichetele reale 
class_labels = list(val_data.class_indices.keys())

# Afișăm Raportul de Clasificare în Terminal
print("\n" + "="*50)
print("RAPORT DE CLASIFICARE MOBILENETV3:")
print("="*50)
print(classification_report(y_true, y_pred, target_names=class_labels))

# 5. Desenăm Matricea de Confuzie
cm = confusion_matrix(y_true, y_pred)

plt.figure(figsize=(10, 8))

sns.heatmap(cm, annot=True, fmt='d', cmap='Greens', xticklabels=class_labels, yticklabels=class_labels)
plt.xlabel('Predicția AI-ului (Predicted)')
plt.ylabel('Realitatea (True)')
plt.title('Matricea de Confuzie - MobileNetV3')
plt.show()
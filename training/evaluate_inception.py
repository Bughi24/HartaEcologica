import tensorflow as tf
from tensorflow.keras.preprocessing.image import ImageDataGenerator
from tensorflow.keras.applications.inception_v3 import preprocess_input
from sklearn.metrics import classification_report, confusion_matrix
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns

print("Încărcăm modelul InceptionV3...")

model = tf.keras.models.load_model('inception_v3_garbage.keras')

# InceptionV3 folosește imagini de 299x299
img_size = 299
batch_size = 32

print("Pregătim datele de validare...")
# Folosim preprocesarea nativă InceptionV3
datagen = ImageDataGenerator(
    preprocessing_function=preprocess_input, 
    validation_split=0.2
)

# Încărcăm setul de validare 
val_data = datagen.flow_from_directory(
    'training/garbage_classification',
    target_size=(img_size, img_size),
    batch_size=batch_size,
    class_mode='categorical',
    subset='validation',
    shuffle=False, 
    seed=42        
)

print("Modelul analizează imaginile. Te rog așteaptă...")
# Generăm predicțiile
preds = model.predict(val_data)

# Transformăm probabilitățile în clase 
y_pred = np.argmax(preds, axis=1)
y_true = val_data.classes
class_labels = list(val_data.class_indices.keys())

# Classification Report
print("\n" + "="*50)
print("RAPORT DE CLASIFICARE INCEPTION V3")
print("="*50)
print(classification_report(y_true, y_pred, target_names=class_labels))

# Confusion Matrix
cm = confusion_matrix(y_true, y_pred)

plt.figure(figsize=(10, 8))
# heatmap
sns.heatmap(cm, annot=True, fmt='d', cmap='Greens', 
            xticklabels=class_labels, 
            yticklabels=class_labels)

plt.xlabel('Predicția Modelului (Ce a zis AI-ul)', fontsize=12)
plt.ylabel('Clasa Adevărată (Ce era de fapt în poză)', fontsize=12)
plt.title('Matrice de Confuzie - InceptionV3', fontsize=14, fontweight='bold')
plt.tight_layout()
plt.show()
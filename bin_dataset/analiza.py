import tensorflow as tf
from tensorflow.keras.preprocessing.image import ImageDataGenerator
import matplotlib.pyplot as plt
import numpy as np
import os

# --- CONFIGURARE ---
IMG_SIZE = 224
DATASET_DIR = 'bin_dataset/dataset'
MODEL_PATH = 'model_intermediar.keras'

model = tf.keras.models.load_model(MODEL_PATH)

# Pregătim datele de validare (fără shuffle pentru a identifica pozele)
test_datagen = ImageDataGenerator(rescale=1./255, validation_split=0.2)
test_generator = test_datagen.flow_from_directory(
    DATASET_DIR,
    target_size=(IMG_SIZE, IMG_SIZE),
    batch_size=1, # Luăm una câte una pentru analiză
    class_mode='binary',
    subset='validation',
    shuffle=False
)

filenames = test_generator.filenames
y_true = test_generator.classes
predictions = model.predict(test_generator).flatten()
y_pred = (predictions > 0.5).astype(int)

# Căutăm greșelile
errors = np.where(y_pred != y_true)[0]
print(f"Am găsit {len(errors)} erori din {len(filenames)} imagini de test.")

# Afișăm primele erori găsite
plt.figure(figsize=(15, 10))
for i, idx in enumerate(errors[:6]): # Afișăm maxim 6 erori
    img_path = os.path.join(DATASET_DIR, filenames[idx])
    img = tf.keras.preprocessing.image.load_img(img_path, target_size=(IMG_SIZE, IMG_SIZE))
    
    plt.subplot(2, 3, i + 1)
    plt.imshow(img)
    plt.title(f"Real: {y_true[idx]} | Pred: {y_pred[idx]}\n{filenames[idx]}")
    plt.axis('off')

plt.tight_layout()
plt.show()
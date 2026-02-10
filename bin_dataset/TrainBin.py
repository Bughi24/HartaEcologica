import tensorflow as tf
from tensorflow.keras.preprocessing.image import ImageDataGenerator
from tensorflow.keras.applications import MobileNetV2
from tensorflow.keras.layers import Dense, GlobalAveragePooling2D, Dropout
from tensorflow.keras.models import Model
import matplotlib.pyplot as plt # Pentru grafice
import os

# --- CONFIGURARE ---
IMG_SIZE = 224
BATCH_SIZE = 32
EPOCHS = 15  # Număr de epoci (ture)
DATASET_DIR = 'bin_dataset/dataset'

# 1. PREGĂTIREA DATELOR
# Împărțim automat: 80% antrenare, 20% validare (testare)
datagen = ImageDataGenerator(
    rescale=1./255,
    rotation_range=20,
    width_shift_range=0.2,
    height_shift_range=0.2,
    horizontal_flip=True,
    validation_split=0.2
)

train_generator = datagen.flow_from_directory(
    DATASET_DIR,
    target_size=(IMG_SIZE, IMG_SIZE),
    batch_size=BATCH_SIZE,
    class_mode='binary', # BINARY pentru că avem doar 2 clase (Pubela vs Nu)
    subset='training'
)

validation_generator = datagen.flow_from_directory(
    DATASET_DIR,
    target_size=(IMG_SIZE, IMG_SIZE),
    batch_size=BATCH_SIZE,
    class_mode='binary',
    subset='validation'
)

# Afișăm ce înseamnă 0 și ce înseamnă 1
print(f"CLASELE DETECTATE: {train_generator.class_indices}")
# Ex: {'bin': 0, 'not_bin': 1} (sau invers, verifică consola!)

# 2. CONSTRUIREA MODELULUI (MobileNetV2)
base_model = MobileNetV2(weights='imagenet', include_top=False, input_shape=(IMG_SIZE, IMG_SIZE, 3))
base_model.trainable = False # Înghețăm baza

x = base_model.output
x = GlobalAveragePooling2D()(x)
x = Dropout(0.2)(x)
# Un singur neuron la final pentru clasificare binară (0 sau 1)
predictions = Dense(1, activation='sigmoid')(x)

model = Model(inputs=base_model.input, outputs=predictions)
model.compile(optimizer='adam', loss='binary_crossentropy', metrics=['accuracy'])

# 3. ANTRENAREA
history = model.fit(
    train_generator,
    epochs=EPOCHS,
    validation_data=validation_generator
)

# 4. SALVAREA MODELULUI PENTRU PC (format .keras)
model.save('model_intermediar.keras')
print("Model salvat ca 'model_intermediar.keras'. Acum îl putem testa!")

# 5. GENERARE GRAFICE (Să vezi cât de bine a învățat)
acc = history.history['accuracy']
val_acc = history.history['val_accuracy']
loss = history.history['loss']
val_loss = history.history['val_loss']

plt.figure(figsize=(8, 8))
plt.subplot(2, 1, 1)
plt.plot(acc, label='Acuratețe Antrenare')
plt.plot(val_acc, label='Acuratețe Validare')
plt.legend(loc='lower right')
plt.ylabel('Acuratețe')
plt.title('Antrenare vs Validare')

plt.subplot(2, 1, 2)
plt.plot(loss, label='Eroare (Loss) Antrenare')
plt.plot(val_loss, label='Eroare (Loss) Validare')
plt.legend(loc='upper right')
plt.ylabel('Eroare')
plt.xlabel('Epoca')
plt.show()
import tensorflow as tf
from tensorflow.keras.preprocessing.image import ImageDataGenerator
from tensorflow.keras.applications import InceptionV3
from tensorflow.keras.applications.inception_v3 import preprocess_input
from tensorflow.keras import layers, models

# Configurare (InceptionV3 preferă 299x299)
img_size = 299
batch_size = 32

# Generatorul de date 
datagen = ImageDataGenerator(
    preprocessing_function=preprocess_input,
    validation_split=0.2
)

# Încărcăm datele de antrenament
print("Încărcăm datele de training...")
train_data = datagen.flow_from_directory(
    'training/garbage_classification',
    target_size=(img_size, img_size),
    batch_size=batch_size,
    class_mode='categorical',
    subset='training'
)

# Încărcăm datele de validare
print("Încărcăm datele de validare...")
val_data = datagen.flow_from_directory(
    'training/garbage_classification',
    target_size=(img_size, img_size),
    batch_size=batch_size,
    class_mode='categorical',
    subset='validation'
)

# Încărcăm baza InceptionV3 (Transfer Learning)
print("Descărcăm arhitectura InceptionV3...")
base_model = InceptionV3(
    input_shape=(img_size, img_size, 3),
    include_top=False, 
    weights='imagenet' 
)

# Înghețăm baza pentru a nu strica ce știe deja
base_model.trainable = False

# Adăugăm "Capul" rețelei pentru clasele noastre de gunoi
num_classes = len(train_data.class_indices)

model = models.Sequential([
    base_model,
    layers.GlobalAveragePooling2D(),
    layers.Dense(256, activation='relu'),  
    layers.Dropout(0.5),                  
    layers.Dense(num_classes, activation='softmax')
])

# Compilarea modelului
model.compile(optimizer=tf.keras.optimizers.Adam(learning_rate=0.001),
              loss='categorical_crossentropy',
              metrics=['accuracy'])

# Antrenarea
print("Începem antrenarea modelului InceptionV3...")
history = model.fit(
    train_data,
    validation_data=val_data,
    epochs=10
)

# Salvarea în formatul modern
model.save('inception_v3_garbage.keras')
print("Modelul a fost salvat cu succes sub numele 'inception_v3_garbage.keras'!")
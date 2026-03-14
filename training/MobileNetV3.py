import tensorflow as tf
from tensorflow.keras.preprocessing.image import ImageDataGenerator
from tensorflow.keras.applications import MobileNetV3Large
from tensorflow.keras import layers, models

img_size = 224
batch_size = 32

datagen = ImageDataGenerator( validation_split=0.2)

train_data = datagen.flow_from_directory(
    'training/garbage_classification',
    target_size=(img_size, img_size),
    batch_size=batch_size,
    class_mode='categorical',
    subset='training'
)

val_data = datagen.flow_from_directory(
    'training/garbage_classification',
    target_size=(img_size, img_size),
    batch_size=batch_size,
    class_mode='categorical',
    subset='validation'
)

base_model = MobileNetV3Large(
    input_shape=(img_size, img_size, 3),
    include_top=False, 
    weights='imagenet'
)

base_model.trainable = False

num_classes = len(train_data.class_indices)

model = models.Sequential([
    base_model,
    layers.GlobalAveragePooling2D(),
    layers.Dropout(0.2),
    layers.Dense(num_classes, activation='softmax')
])

model.compile(optimizer='adam', loss='categorical_crossentropy', metrics=['accuracy'])

print("Incepe antrenarea modelului MobileNetV3Large...")

history = model.fit(
    train_data,
    validation_data=val_data,
    epochs=10
)

model.save('mobilenet_v3_garbage.keras')
print("Modelul a fost salvat cu succes în noul format .keras!")
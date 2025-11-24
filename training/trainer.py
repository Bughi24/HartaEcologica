# pyright: ignore[reportMissingImports]
import tensorflow as tf
from tensorflow.keras.preprocessing.image import ImageDataGenerator
from tensorflow.keras.models import Sequential  
from tensorflow.keras.layers import Conv2D, MaxPooling2D, Flatten, Dense
import os

# Set parameters
img_size = 150
batch_size = 16

# Prepare data generators
datagen = ImageDataGenerator(rescale=1./255, validation_split=0.2)

# Load training data
train_data = datagen.flow_from_directory(
   'training/garbage_classification', 
    target_size=(img_size, img_size), 
    batch_size=batch_size, 
    class_mode='categorical' , 
    subset='training' 
)

# Load validation data
val_data = datagen.flow_from_directory(
   'training/garbage_classification',
    target_size=(img_size, img_size),
    batch_size=batch_size,
    class_mode='categorical',
    subset='validation'
)

# Building the model
model = Sequential([
    Conv2D(32, (3, 3), activation='relu', input_shape=(img_size, img_size, 3)), 
    MaxPooling2D((2, 2)), 
    Conv2D(64, (3, 3), activation='relu'),
    MaxPooling2D((2, 2)),
    Flatten(), 
    Dense(128, activation='relu'),
    Dense(64, activation='relu'),
    Dense(train_data.num_classes, activation='softmax')
])

model.compile(optimizer='adam', loss='categorical_crossentropy', metrics=['accuracy']) 

model.fit(train_data, validation_data=val_data, epochs=10)

model.save('garbage_classification_model.h5')

print("Model training complete and saved as 'garbage_classification_model.h5'")
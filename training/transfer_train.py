import tensorflow as tf
from tensorflow.keras.preprocessing.image import ImageDataGenerator
from tensorflow.keras.models import Model
from tensorflow.keras.layers import Dense, GlobalAveragePooling2D,Dense,Dropout
from tensorflow.keras.applications import MobileNetV2
from tensorflow.keras.callbacks import EarlyStopping, ModelCheckpoint

# Set parameters
img_size = 150
batch_size = 16

# Prepare data generators
datagen= ImageDataGenerator(rescale=1./255, validation_split=0.2)

# Load training data
train_data = datagen.flow_from_directory(
   'training/garbage_classification',
    target_size=(img_size, img_size),
    batch_size=batch_size,
    class_mode='categorical',
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
base_model = MobileNetV2(weights='imagenet', include_top=False, input_shape=(img_size, img_size, 3)) # Using MobileNetV2 as base model
base_model.trainable = False # Freeze the base model

# Adding custom layers on top of the base model
x = base_model.output
x = GlobalAveragePooling2D()(x)
x = Dense(128, activation='relu')(x)
x = Dropout(0.4)(x)
predictions = Dense(train_data.num_classes, activation='softmax')(x)

model = Model(inputs=base_model.input, outputs=predictions) 

model.compile(optimizer='adam', loss='categorical_crossentropy', metrics=['accuracy'])

early_stopping = EarlyStopping(monitor='val_loss', patience=4, restore_best_weights=True)

model.fit(train_data, validation_data=val_data, epochs=20, callbacks=[early_stopping])

model.save('garbage_classification_model_v2.h5')
print("Model training complete and saved as 'garbage_classification_model_v2.h5'")
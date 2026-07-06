import tensorflow as tf
from tensorflow.keras import layers, models

# PARAMETRI
IMG_SIZE = 224
BATCH_SIZE = 32
EPOCHS = 10

# DATASET 
# Incarcam datele
train_ds = tf.keras.utils.image_dataset_from_directory(
    'training/garbage_classification',
    validation_split=0.2,
    subset="training",
    seed=42,
    image_size=(IMG_SIZE, IMG_SIZE),
    batch_size=BATCH_SIZE,
    label_mode='categorical'
)

val_ds = tf.keras.utils.image_dataset_from_directory(
    'training/garbage_classification',
    validation_split=0.2,
    subset="validation",
    seed=42,
    image_size=(IMG_SIZE, IMG_SIZE),
    batch_size=BATCH_SIZE,
    label_mode='categorical'
)

# PROPOSED APPROACH
# Folosim un strat de preprocesare specific pentru MobileNetV2
preprocess_input = tf.keras.applications.mobilenet_v2.preprocess_input

def build_paper_model(num_classes):
    # Definirea intrarii
    inputs = tf.keras.Input(shape=(IMG_SIZE, IMG_SIZE, 3))
    
    # Preprocesare (Normalizare la [-1, 1])
    x = preprocess_input(inputs)
    
    # Modelul de baza (MobileNetV2)
    base_model = tf.keras.applications.MobileNetV2(
        input_shape=(IMG_SIZE, IMG_SIZE, 3),
        include_top=False,
        weights='imagenet'
    )
    base_model.trainable = False
    
    # Adaugarea capului de clasificare
    x = base_model(x, training=False)
    x = layers.GlobalAveragePooling2D()(x)
    x = layers.Dropout(0.2)(x)
    outputs = layers.Dense(num_classes, activation='softmax')(x)
    
    model = tf.keras.Model(inputs, outputs)
    return model

# EXPERIMENTS
num_classes = len(train_ds.class_names)
model = build_paper_model(num_classes)

model.compile(optimizer='adam', loss='categorical_crossentropy', metrics=['accuracy'])

# Start Training
history = model.fit(train_ds, validation_data=val_ds, epochs=EPOCHS)

# EXPORT 
model.save('final_waste_model.keras')
print("Antrenare reusita! Modelul este gata pentru articol.")     
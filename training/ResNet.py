import tensorflow as tf
from tensorflow.keras import layers, models

# 1. PARAMETRI (Sect 6.a)
IMG_SIZE = 224
BATCH_SIZE = 32
EPOCHS = 10

# 2. DATASET (Asigură-te că folderul e corect)
train_ds = tf.keras.utils.image_dataset_from_directory(
    'training/garbage_classification',
    validation_split=0.2,
    subset="training",
    seed=123,
    image_size=(IMG_SIZE, IMG_SIZE),
    batch_size=BATCH_SIZE,
    label_mode='categorical'
)

val_ds = tf.keras.utils.image_dataset_from_directory(
    'training/garbage_classification',
    validation_split=0.2,
    subset="validation",
    seed=123,
    image_size=(IMG_SIZE, IMG_SIZE),
    batch_size=BATCH_SIZE,
    label_mode='categorical'
)

# 3. PROPOSED APPROACH: ResNet50 (Sect 4)
def build_resnet_model(num_classes):
    inputs = tf.keras.Input(shape=(IMG_SIZE, IMG_SIZE, 3))
    
    # Preprocesarea specifică ResNet50 (conversie RGB -> BGR și centrare medie)
    x = tf.keras.applications.resnet50.preprocess_input(inputs)
    
    # Backbone-ul ResNet50
    base_model = tf.keras.applications.ResNet50(
        include_top=False,
        weights='imagenet',
        input_tensor=x
    )
    base_model.trainable = False # Înghețăm straturile pentru Transfer Learning
    
    # Capul de clasificare
    x = layers.GlobalAveragePooling2D()(base_model.output)
    x = layers.BatchNormalization()(x) # Adăugăm stabilitate
    x = layers.Dropout(0.3)(x)
    outputs = layers.Dense(num_classes, activation='softmax')(x)
    
    model = tf.keras.Model(inputs, outputs, name="ResNet50_Waste_Classifier")
    return model

# 4. TRAINING
num_classes = len(train_ds.class_names)
model = build_resnet_model(num_classes)

model.compile(
    optimizer=tf.keras.optimizers.Adam(learning_rate=0.0001),
    loss='categorical_crossentropy',
    metrics=['accuracy']
)

print("Începe antrenarea cu ResNet50...")
history = model.fit(train_ds, validation_data=val_ds, epochs=EPOCHS)

# 5. EXPORT
model.save('resnet50_waste_model.keras')
print("Modelul ResNet50 a fost salvat!")
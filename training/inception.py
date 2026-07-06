import tensorflow as tf
import numpy as np
from tensorflow.keras.preprocessing.image import ImageDataGenerator
from tensorflow.keras.models import Model
from tensorflow.keras.layers import Dense, GlobalAveragePooling2D, BatchNormalization, Dropout
from tensorflow.keras.applications import InceptionV3
from tensorflow.keras.applications.inception_v3 import preprocess_input
from tensorflow.keras.callbacks import EarlyStopping, ModelCheckpoint, ReduceLROnPlateau
from sklearn.utils.class_weight import compute_class_weight
from sklearn.metrics import classification_report

IMG_SIZE = 299  
BATCH_SIZE = 32
EPOCHS = 25

train_datagen = ImageDataGenerator(
    preprocessing_function=preprocess_input,
    validation_split=0.2
)

val_datagen = ImageDataGenerator(
    preprocessing_function=preprocess_input,
    validation_split=0.2
)

train_data = train_datagen.flow_from_directory(
    'training/garbage_classification',
    target_size=(IMG_SIZE, IMG_SIZE),
    batch_size=BATCH_SIZE,
    class_mode='categorical',
    subset='training',
    seed=42
)

val_data = val_datagen.flow_from_directory(
    'training/garbage_classification',
    target_size=(IMG_SIZE, IMG_SIZE),
    batch_size=BATCH_SIZE,
    class_mode='categorical',
    subset='validation',
    shuffle=False,
    seed=42
)

classes = list(train_data.class_indices.keys())
num_classes = len(classes)

# Class weights
labels_raw = train_data.classes
class_weights = compute_class_weight(
    class_weight='balanced',
    classes=np.unique(labels_raw),
    y=labels_raw
)
class_weights = dict(enumerate(class_weights))
print("\nClass Weights:", class_weights, "\n")

# Model
base_model = InceptionV3(
    input_shape=(IMG_SIZE, IMG_SIZE, 3),
    include_top=False,
    weights='imagenet'
)

# Fine-tuning ultimele 40 straturi
for layer in base_model.layers[:-40]:
    layer.trainable = False
for layer in base_model.layers[-40:]:
    layer.trainable = True

x = base_model.output
x = GlobalAveragePooling2D()(x)
x = BatchNormalization()(x)
x = Dense(256, activation='relu')(x)
x = Dropout(0.5)(x)
outputs = Dense(num_classes, activation='softmax')(x)

model = Model(
    inputs=base_model.input,
    outputs=outputs,
    name="InceptionV3"
)

model.compile(
    optimizer=tf.keras.optimizers.Adam(learning_rate=0.0005),
    loss='categorical_crossentropy',
    metrics=['accuracy']
)

callbacks = [
    EarlyStopping(monitor='val_loss', patience=5, restore_best_weights=True),
    ReduceLROnPlateau(monitor='val_loss', factor=0.3, patience=2, min_lr=1e-6),
    ModelCheckpoint("best_inception_no_aug.h5", monitor='val_loss', save_best_only=True)
]

print("Incepe antrenarea InceptionV3 (FĂRĂ augmentare) + Fine-tuning...")
model.fit(
    train_data,
    validation_data=val_data,
    epochs=EPOCHS,
    class_weight=class_weights,
    callbacks=callbacks
)

model.save("inception_v3_no_aug.keras")
print("Model salvat!")

# EVALUARE
print("Generare raport...")
preds = model.predict(val_data)
y_pred = np.argmax(preds, axis=1)
y_true = val_data.classes

report = classification_report(y_true, y_pred, target_names=classes)
print(report)

with open("inception_no_aug_report.txt", "w", encoding="utf-8") as f:
    f.write(report)
print("Raport salvat in inception_no_aug_report.txt!")
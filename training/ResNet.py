import tensorflow as tf
import numpy as np
from tensorflow.keras import layers, models
from tensorflow.keras.preprocessing.image import ImageDataGenerator
from tensorflow.keras.applications.resnet50 import preprocess_input
from tensorflow.keras.callbacks import EarlyStopping, ModelCheckpoint, ReduceLROnPlateau
from sklearn.utils.class_weight import compute_class_weight
from sklearn.metrics import classification_report

IMG_SIZE = 224
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
def build_resnet_model(num_classes):
    base_model = tf.keras.applications.ResNet50(
        input_shape=(IMG_SIZE, IMG_SIZE, 3),
        include_top=False,
        weights='imagenet'
    )

    base_model.trainable = False

    x = base_model.output
    x = layers.GlobalAveragePooling2D()(x)
    x = layers.BatchNormalization()(x)
    x = layers.Dropout(0.3)(x)
    outputs = layers.Dense(num_classes, activation='softmax')(x)

    model = tf.keras.Model(
        inputs=base_model.input,
        outputs=outputs,
        name="ResNet50"
    )
    return model

model = build_resnet_model(num_classes)

model.compile(
    optimizer=tf.keras.optimizers.Adam(learning_rate=0.0005),
    loss='categorical_crossentropy',
    metrics=['accuracy']
)

callbacks = [
    EarlyStopping(monitor='val_loss', patience=5, restore_best_weights=True),
    ReduceLROnPlateau(monitor='val_loss', factor=0.3, patience=2, min_lr=1e-6),
    ModelCheckpoint("best_resnet50.h5", monitor='val_loss', save_best_only=True)
]

print("Începe antrenarea cu ResNet50...")
model.fit(
    train_data,
    validation_data=val_data,
    epochs=EPOCHS,
    class_weight=class_weights,
    callbacks=callbacks
)

model.save('resnet50.keras')
print("Modelul ResNet50 a fost salvat!")

# EVALUARE
print("Generare raport...")
preds = model.predict(val_data)
y_pred = np.argmax(preds, axis=1)
y_true = val_data.classes

report = classification_report(y_true, y_pred, target_names=classes)
print(report)

with open("resnet50_report.txt", "w", encoding="utf-8") as f:
    f.write(report)
print("Raport salvat in resnet50_report.txt!")
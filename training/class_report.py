import tensorflow as tf
import numpy as np
from tensorflow.keras.preprocessing.image import ImageDataGenerator
from sklearn.metrics import classification_report

IMG_SIZE = 150
BATCH_SIZE = 32

val_datagen = ImageDataGenerator(
    rescale=1./255,
    validation_split=0.2
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

classes = list(val_data.class_indices.keys())

model = tf.keras.models.load_model('garbage_classification_model_v2_newmodel.h5')
print(model.input_shape)

preds = model.predict(val_data)
y_pred = np.argmax(preds, axis=1)
y_true = val_data.classes

report = classification_report(y_true, y_pred, target_names=classes, digits=4)
print(report)

with open("garbage_classification_model_v2_newmodel.txt", "w", encoding="utf-8") as f:
    f.write(report)
print("Raport salvat!")
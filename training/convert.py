import tensorflow as tf
model = tf.keras.models.load_model('garbage_classification_model_v2.h5')


converter = tf.lite.TFLiteConverter.from_keras_model(model)
tflite_model = converter.convert()
with open('garbage_classification_model_v2.tflite', 'wb') as f:
    f.write(tflite_model)
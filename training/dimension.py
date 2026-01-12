import tensorflow as tf
model = tf.keras.models.load_model("garbage_classification_model_v2.h5")
print(model.input_shape)

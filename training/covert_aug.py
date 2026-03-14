import tensorflow as tf

# 1. Încarcă modelul tău antrenat (schimbă numele fișierului)
model = tf.keras.models.load_model('garbage_model_augmentation.h5')

# 2. Inițializează convertorul
converter = tf.lite.TFLiteConverter.from_keras_model(model)

# ,Optimizare pentru mobil - reduce dimensiunea fără să piardă multă acuratețe
converter.optimizations = [tf.lite.Optimize.DEFAULT]

# 3. Convertește
tflite_model = converter.convert()

# 4. Salvează fișierul .tflite
with open('model_aug.tflite', 'wb') as f:
    f.write(tflite_model)

print("Conversie reușită! Acum poți muta 'model_aug.tflite' în Flutter.")
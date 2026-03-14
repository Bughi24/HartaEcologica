import tensorflow as tf

print("Încărcăm modelul .h5...")
model = tf.keras.models.load_model("garbage_model_augmentation.h5")

print("Inițializăm convertorul TFLite...")
converter = tf.lite.TFLiteConverter.from_keras_model(model)

# --- REZOLVAREA ERORII DE FULLY_CONNECTED ---
# Aceste linii forțează convertorul să folosească doar operațiuni de bază 
# și să permită fallback-ul către operațiuni compatibile mai vechi.
converter.target_spec.supported_ops = [
    tf.lite.OpsSet.TFLITE_BUILTINS,
    tf.lite.OpsSet.SELECT_TF_OPS
]

# Dezactivăm temporar optimizările agresive pentru a garanta că rulează
converter.optimizations = [] 

print("Convertim modelul (poate dura un minut)...")
tflite_model = converter.convert()

with open("model_augmentation.tflite", "wb") as f:
    f.write(tflite_model)

print("Succes! Fișierul model_aug.tflite a fost salvat și este gata pentru Flutter.")
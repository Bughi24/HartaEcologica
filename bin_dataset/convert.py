import tensorflow as tf
import os

# 1. Încărcăm modelul pe care tocmai l-ai antrenat
# Asigură-te că fișierul 'model_intermediar.keras' este lângă acest script!
input_file = 'model_intermediar.keras'

if not os.path.exists(input_file):
    print(f"❌ EROARE: Nu găsesc fișierul '{input_file}'.")
    print("Te rog verifică dacă ai rulat antrenarea și s-a salvat modelul.")
    exit()

print("1. Se încarcă modelul Keras...")
model = tf.keras.models.load_model(input_file)

# 2. Îl convertim la formatul TensorFlow Lite
print("2. Se convertește modelul (poate dura câteva secunde)...")
converter = tf.lite.TFLiteConverter.from_keras_model(model)
tflite_model = converter.convert()

# 3. Îl salvăm pe disc
output_file = 'bin_model.tflite'
with open(output_file, 'wb') as f:
    f.write(tflite_model)

print(f"\n✅ SUCCES! Fișierul '{output_file}' a fost creat.")
print("Acum copiază acest fișier în proiectul Flutter în 'assets/model/'.")

# --- RECUPERARE LABELS (Opțional, dacă ai uitat ordinea) ---
# Dacă nu mai știi care e 0 și care e 1 (pubela vs altele), 
# și folderul tău e 'dataset/altele' și 'dataset/pubela':
# De obicei sunt ordonate alfabetic:
# 0: altele
# 1: pubela
print("\nNu uita să verifici fișierul 'bin_labels.txt'. Ordinea standard alfabetică este:")
print("altele")
print("pubela")
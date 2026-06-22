# Păstrează clasele TensorFlow Lite pentru a evita erorile R8
-keep class org.tensorflow.lite.** { *; }
-keep class org.tensorflow.lite.gpu.** { *; }

# Ignoră avertismentele pentru clasele lipsă (cele care cauzează eroarea ta)
-dontwarn org.tensorflow.lite.gpu.**
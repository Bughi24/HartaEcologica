import json
from tensorflow.keras.preprocessing.image import ImageDataGenerator

train = ImageDataGenerator(rescale=1./255).flow_from_directory(
    "HartaEcologica/training/garbage_classification"
)

print(train.class_indices)

import tensorflow as tf
from tensorflow.keras.preprocessing.image import ImageDataGenerator
from sklearn.metrics import classification_report, confusion_matrix
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns

# Load the trained model
model= tf.keras.models.load_model('garbage_classification_model_sequential_augmented.h5')

img_size = 150
batch_size = 16

# Prepare the test data generator
datagen = ImageDataGenerator(rescale=1./255, validation_split=0.2)

# Load test data
test_data = datagen.flow_from_directory(
   'training/garbage_classification',
   target_size=(img_size, img_size),
   batch_size=batch_size,
   class_mode='categorical',
   subset='validation',
   shuffle=False
)

# Evaluate the model on test data
preds = model.predict(test_data)
y_pred = np.argmax(preds, axis=1)
y_true = test_data.classes
class_labels = list(test_data.class_indices.keys())

print("Final Evaluation on Test Data:")
print(classification_report(y_true, y_pred, target_names=class_labels))

# Confusion matrix
cm = confusion_matrix(y_true, y_pred)
plt.figure(figsize=(10, 8))
sns.heatmap(cm, annot=True, fmt='d', xticklabels=class_labels, yticklabels=class_labels, cmap='Blues')
plt.ylabel('Actual')
plt.xlabel('Predicted')
plt.title('Confusion Matrix')
plt.show()
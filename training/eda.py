import os
import numpy as np
import matplotlib.pyplot as plt
import pandas as pd
import seaborn as sns
from PIL import Image

# Function to plot color histogram of an image
def plot_color_histogram(image_path):
    img = Image.open(image_path)
    img_array = np.array(img)
    colors = ('r', 'g', 'b')
    plt.figure(figsize=(10, 5))
    for i, color in enumerate(colors):
        plt.hist(img_array[:, :, i].ravel(), bins=256, color=color, alpha=0.5)
    plt.title('Color Histogram')
    plt.xlabel('Color value')
    plt.ylabel('Frequency')
    plt.show()


basea_dir = 'training/garbage_classification'

classes = os.listdir(basea_dir)
print(f"Classes found: {classes}")

# number of images per class
num_images = {c: len(os.listdir(os.path.join(basea_dir, c))) for c in classes}
df_counts = pd.DataFrame.from_dict(num_images, orient='index', columns=['Nr_images'])

plt.figure(figsize=(10, 6))
sns.barplot(x=df_counts.index, y=df_counts['Nr_images'], palette='viridis')
plt.title('Number of Images per Class')
plt.xlabel('Class')
plt.ylabel('Number of Images')
plt.show()

plt.figure(figsize=(12, 12))
# Display sample images from each class
for i, c in enumerate(classes):
    img_path = os.path.join(basea_dir, c, os.listdir(os.path.join(basea_dir, c))[0])
    img = Image.open(img_path)
    plt.subplot(3, 4, i + 1)
    plt.imshow(img)
    plt.title(c)
    plt.axis('off')

plt.tight_layout()
plt.show()

# Analyze image dimensions
img_shapes = []
for c in classes:
    folder_path = os.path.join(basea_dir, c)
    for img_name in os.listdir(folder_path)[:100]:
        img_path = os.path.join(folder_path, img_name)
        with Image.open(img_path) as img:
            img_shapes.append(img.size)
sizes_df = pd.DataFrame(img_shapes, columns=['Width', 'Height'])

# Plot distribution of image dimensions
plt.figure(figsize=(10, 6))
sns.scatterplot(data=sizes_df, x='Width', y='Height', alpha=0.6)
plt.title('Image Dimensions Distribution')
plt.show()

samplez_img = os.path.join(basea_dir,'plastic', os.listdir(os.path.join(basea_dir,'plastic'))[0])
plot_color_histogram(samplez_img)

corr = sizes_df.corr()
plt.figure(figsize=(8, 6))
sns.heatmap(corr, annot=True, cmap="coolwarm", fmt=".2f")
plt.title("Correlation Matrix of Image Dimensions")
plt.show()
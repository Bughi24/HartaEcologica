import matplotlib.pyplot as plt
import numpy as np
from matplotlib.patches import Patch

labels = [
    'CNN\n(2ds)', 'MNet2\n(2ds)',
    'CNN', 'CNN\n+Aug',
    'MNet2', 'MNet2\n+Aug',
    'MNet3', 'IncV3',
    'IncV3\n+Aug', 'EffNet',
    'ResNet', 'ResNet\n+Aug'
]

accuracies = [0.91, 0.84,
              0.91, 0.79,
              0.95, 0.98,
              0.95, 0.96,
              0.99, 0.95,
              0.96, 0.99]

colors = ['#A5D6A7' if '+Aug' not in l else '#2E7D32'
          for l in labels]

fig, ax = plt.subplots(figsize=(12, 5))
bars = ax.bar(labels, accuracies, color=colors,
              edgecolor='white', linewidth=0.8)

for bar, val in zip(bars, accuracies):
    ax.text(
        bar.get_x() + bar.get_width() / 2,
        bar.get_height() + 0.005,
        f'{val:.2f}',
        ha='center', va='bottom',
        fontsize=8, fontweight='bold',
        color='#333333'
    )

ax.set_ylim(0.70, 1.05)
ax.set_ylabel('Accuracy', fontsize=11)
ax.set_xlabel('Architecture', fontsize=11)
ax.set_title('Accuracy Comparison Across Architectures',
             fontsize=12, fontweight='bold', pad=15)

ax.axhline(y=0.95, color='gray', linestyle='--',
           linewidth=0.8, alpha=0.6)
ax.axhline(y=0.99, color='#2E7D32', linestyle='--',
           linewidth=0.8, alpha=0.6)

legend_elements = [
    Patch(facecolor='#2E7D32', label='With augmentation + fine-tuning'),
    Patch(facecolor='#A5D6A7', label='Without augmentation')
]
ax.legend(handles=legend_elements, fontsize=9,
          loc='lower right')

ax.spines['top'].set_visible(False)
ax.spines['right'].set_visible(False)
ax.set_facecolor('#fafafa')
fig.patch.set_facecolor('white')

plt.tight_layout()
plt.savefig('acc_comparison.png', dpi=150,
            bbox_inches='tight')
print("Grafic salvat!")
plt.show()
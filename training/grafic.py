import matplotlib.pyplot as plt
import numpy as np

experimente = [
    "1. CNN\n(1 dataset)",
    "2. MobileNetV2\n(1 dataset)",
    "3. CNN\n(2 datasets)",
    "4. MobileNetV2\n(2 datasets)",
    "5. CNN\n(4 datasets)",
    "6. MobileNetV2\n(4 datasets)",
    "7. MobileNetV2\n+Augmentare",
    "8. CNN\n+Augmentare",
    "9. MobileNetV3",
    "10. InceptionV3",
    "11. EfficientNet\n+MobileNetV2",
    "12. ResNet50",
]

acuratete = [0.67, 0.90, 0.91, 0.84, 0.91, 0.95, 0.98, 0.79, 0.95, 0.96, 0.95, 0.96]

culori = ['#ef5350' if a < 0.90 else '#ffb300' if a < 0.95 else '#66bb6a' if a < 0.98 else '#2e7d32' for a in acuratete]

fig, ax = plt.subplots(figsize=(14, 6))

bars = ax.bar(range(len(experimente)), acuratete, color=culori, edgecolor='white', linewidth=0.8)

for bar, val in zip(bars, acuratete):
    ax.text(
        bar.get_x() + bar.get_width() / 2,
        bar.get_height() + 0.005,
        f'{val:.2f}',
        ha='center', va='bottom',
        fontsize=9, fontweight='bold', color='#333333'
    )

ax.set_xticks(range(len(experimente)))
ax.set_xticklabels(experimente, fontsize=8, ha='center')
ax.set_ylim(0.60, 1.02)
ax.set_ylabel('Acuratețe', fontsize=11)
ax.set_title('Evoluția acurateței pe parcursul experimentelor de antrenare', fontsize=13, fontweight='bold', pad=15)
ax.axhline(y=0.95, color='gray', linestyle='--', linewidth=0.8, alpha=0.6, label='Prag 0.95')
ax.axhline(y=0.98, color='#2e7d32', linestyle='--', linewidth=0.8, alpha=0.6, label='Model final (0.98)')
ax.legend(fontsize=9)
ax.spines['top'].set_visible(False)
ax.spines['right'].set_visible(False)
ax.set_facecolor('#fafafa')
fig.patch.set_facecolor('white')

plt.tight_layout()
plt.savefig('evolutie_acuratete.png', dpi=150, bbox_inches='tight')
print("Grafic salvat!")
plt.show()
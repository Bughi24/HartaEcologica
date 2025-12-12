import os
import uuid

base_path = "C:\\Users\\bughi\\Downloads\\archive(9)\\images\\images\\plastic_cup_lids"   # <- aici ai datasetul cu nume duplicate

valid_ext = [".jpg", ".jpeg", ".png"]

for category in os.listdir(base_path):
    cat_path = os.path.join(base_path, category)
    
    if not os.path.isdir(cat_path):
        continue
    
    print(f"Processing category: {category}")
    
    for filename in os.listdir(cat_path):
        old_path = os.path.join(cat_path, filename)
        
        # extrage extensia
        ext = os.path.splitext(filename)[1].lower()
        if ext not in valid_ext:
            continue
        
        # generează nume unic
        new_name = f"{uuid.uuid4()}{ext}"
        new_path = os.path.join(cat_path, new_name)
        
        # redenumește fișierul
        os.rename(old_path, new_path)

print("\nRedenumire completă! Toate fișierele au nume unice.")

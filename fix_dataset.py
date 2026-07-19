import json
import os
import shutil

# Correct local project folder path with space
local_path = "/Users/dimasps32/Developer/apple-dev/challenge-apple-dev/challenge-4/a-new-hope/SignLanguageApp/BISINDO Dataset.createml"

if os.path.exists(local_path):
    base_path = local_path
    print(f"Using dataset in project directory: {base_path}")
else:
    print(f"Error: Path {local_path} does not exist.")
    exit(1)

def fix_file(file_path):
    print(f"\nProcessing file: {file_path}")
    backup_path = file_path + ".bak"
    if not os.path.exists(backup_path):
        print(f"Creating backup at {backup_path}")
        shutil.copy2(file_path, backup_path)
    else:
        print(f"Backup already exists at {backup_path}")
    
    with open(file_path, "r", encoding="utf-8") as f:
        data = json.load(f)
        
    print(f"Loaded {len(data)} items from JSON.")
    fixed_data = []
    string_coord_count = 0
    
    for idx, item in enumerate(data):
        new_item = {}
        image_file = None
        for k in ["image", "imagefilename", "imagefilenamefilename"]:
            if k in item:
                image_file = item[k]
                break
        
        if not image_file:
            print(f"Warning: No image filename found at index {idx}")
            continue
            
        new_item["image"] = image_file
        
        new_annotations = []
        if "annotations" in item:
            for ann in item["annotations"]:
                new_ann = {}
                if "label" in ann:
                    new_ann["label"] = ann["label"]
                if "coordinates" in ann:
                    coords = ann["coordinates"]
                    new_coords = {}
                    for coord_key in ["x", "y", "width", "height"]:
                        if coord_key in coords:
                            val = coords[coord_key]
                            if isinstance(val, str):
                                new_coords[coord_key] = float(val)
                                string_coord_count += 1
                            else:
                                new_coords[coord_key] = val
                    new_ann["coordinates"] = new_coords
                new_annotations.append(new_ann)
        new_item["annotations"] = new_annotations
        fixed_data.append(new_item)
        
    with open(file_path, "w", encoding="utf-8") as f:
        json.dump(fixed_data, f)
        
    print(f"Successfully fixed and saved {file_path}")
    print(f"Fixed {string_coord_count} coordinates that were strings.")

def handle_walk_error(err):
    print(f"Error walking directory: {err}")

print(f"Scanning {base_path} for '_annotations.createml.json'...")
found_any = False
for root, dirs, files in os.walk(base_path, onerror=handle_walk_error):
    for file in files:
        if file == "_annotations.createml.json":
            file_path = os.path.join(root, file)
            fix_file(file_path)
            found_any = True
if not found_any:
    print("No '_annotations.createml.json' files found in the dataset folder.")

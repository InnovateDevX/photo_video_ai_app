from PIL import Image
import os

images_to_convert = [
    r"d:\andriod_practice\trail_ai_app\assets\images\Sticker_logo.png",
    r"d:\andriod_practice\trail_ai_app\assets\onboarding\2.jpg",
    r"d:\andriod_practice\trail_ai_app\assets\onboarding\3.jpg",
    r"d:\andriod_practice\trail_ai_app\assets\onboarding\onboarding_1.jpg"
]

for img_path in images_to_convert:
    if os.path.exists(img_path):
        base, ext = os.path.splitext(img_path)
        webp_path = base + ".webp"
        
        # Open and convert
        with Image.open(img_path) as img:
            img.save(webp_path, "webp", quality=80)
            
        print(f"Converted {img_path} to {webp_path}")
        
        # Delete original
        os.remove(img_path)
        print(f"Deleted original {img_path}")
    else:
        print(f"File not found: {img_path}")

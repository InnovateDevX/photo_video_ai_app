import os
import sys
import json
import urllib.parse
import uuid

# 1. Install/Ensure dependencies
try:
    import requests
except ImportError:
    print("Installing 'requests' library...")
    os.system(sys.executable + " -m pip install requests")
    import requests

try:
    import firebase_admin
    from firebase_admin import credentials, storage
except ImportError:
    print("Installing 'firebase-admin' library...")
    os.system(sys.executable + " -m pip install firebase-admin")
    import firebase_admin
    from firebase_admin import credentials, storage

# 2. Setup Firebase credentials
service_account_path = "imagegen-trail-firebase-adminsdk-fbsvc-47eb9e285d.json"
bucket_name = "imagegen-trail.firebasestorage.app"

if not os.path.exists(service_account_path):
    print(f"Error: Service account file '{service_account_path}' not found in the current directory.")
    sys.exit(1)

cred = credentials.Certificate(service_account_path)
firebase_admin.initialize_app(cred, {
    'storageBucket': bucket_name
})

bucket = storage.bucket()

# 3. Input JSON list of dresses
raw_json = """[
  {
    "id": 1,
    "imageUrl": "https://firebasestorage.googleapis.com/v0/b/facesnap-b2df8.firebasestorage.app/o/Dress%20Images%2FCocktail%20Dresses%2Fc1.png?alt=media&token=7d804e3b-bcca-4fa5-936b-5536d01376ce%22",
    "category": "Cocktail Dresses",
    "isLocked": true
  },
  {
    "id": 2,
    "imageUrl": "https://firebasestorage.googleapis.com/v0/b/facesnap-b2df8.firebasestorage.app/o/Dress%20Images%2FCocktail%20Dresses%2Fc2.png?alt=media&token=a4f2e5fa-8cf5-4afe-96f1-43dd258575e0%22",
    "category": "Cocktail Dresses",
    "isLocked": false
  },
  {
    "id": 3,
    "imageUrl": "https://firebasestorage.googleapis.com/v0/b/facesnap-b2df8.firebasestorage.app/o/Dress%20Images%2FCocktail%20Dresses%2Fc3.png?alt=media&token=f1fc2334-3930-483a-814a-fd45654243ac%22",
    "category": "Cocktail Dresses",
    "isLocked": true
  },
  {
    "id": 4,
    "imageUrl": "https://firebasestorage.googleapis.com/v0/b/facesnap-b2df8.firebasestorage.app/o/Dress%20Images%2FCocktail%20Dresses%2Fc4.png?alt=media&token=cd23da62-0168-490d-a55c-c1ee68c36d79%22",
    "category": "Cocktail Dresses",
    "isLocked": false
  },
  {
    "id": 5,
    "imageUrl": "https://firebasestorage.googleapis.com/v0/b/facesnap-b2df8.firebasestorage.app/o/Dress%20Images%2FCocktail%20Dresses%2Fc5.png?alt=media&token=c3646b51-a9b3-4d02-ab98-8c2d7f5223be%22",
    "category": "Cocktail Dresses",
    "isLocked": false
  },
  {
    "id": 6,
    "imageUrl": "https://firebasestorage.googleapis.com/v0/b/facesnap-b2df8.firebasestorage.app/o/Dress%20Images%2FMaxi%20Dresses%2Fm1.png?alt=media&token=b9cc7168-a423-461b-be5a-b67392b96ca1%22",
    "category": "Maxi Dresses",
    "isLocked": false
  },
  {
    "id": 7,
    "imageUrl": "https://firebasestorage.googleapis.com/v0/b/facesnap-b2df8.firebasestorage.app/o/Dress%20Images%2FMaxi%20Dresses%2Fm2.png?alt=media&token=d9d6054a-82fd-4439-ae45-acc9cf289a26%22",
    "category": "Maxi Dresses",
    "isLocked": false
  },
  {
    "id": 8,
    "imageUrl": "https://firebasestorage.googleapis.com/v0/b/facesnap-b2df8.firebasestorage.app/o/Dress%20Images%2FMaxi%20Dresses%2Fm3.png?alt=media&token=2f809304-b98c-4a03-b113-2f16fa95feaf%22",
    "category": "Maxi Dresses",
    "isLocked": true
  },
  {
    "id": 9,
    "imageUrl": "https://firebasestorage.googleapis.com/v0/b/facesnap-b2df8.firebasestorage.app/o/Dress%20Images%2FMaxi%20Dresses%2Fm4.png?alt=media&token=57dd83b5-07d8-4e46-8dee-81cc82aaa3c1%22",
    "category": "Maxi Dresses",
    "isLocked": true
  },
  {
    "id": 10,
    "imageUrl": "https://firebasestorage.googleapis.com/v0/b/facesnap-b2df8.firebasestorage.app/o/Dress%20Images%2FMaxi%20Dresses%2Fm5.png?alt=media&token=0cdb1a4e-5eb5-4b66-83dc-0520d6d494ae%22",
    "category": "Maxi Dresses",
    "isLocked": true
  },
  {
    "id": 11,
    "imageUrl": "https://firebasestorage.googleapis.com/v0/b/facesnap-b2df8.firebasestorage.app/o/Dress%20Images%2FOff%20Shoulder%20Dresses%2Fo1.png?alt=media&token=c204131a-660b-4dc0-a2c4-638d54140a17%22",
    "category": "Off Shoulder Dresses",
    "isLocked": false
  },
  {
    "id": 12,
    "imageUrl": "https://firebasestorage.googleapis.com/v0/b/facesnap-b2df8.firebasestorage.app/o/Dress%20Images%2FOff%20Shoulder%20Dresses%2Fo2.png?alt=media&token=83d5f305-4ac2-4537-b6f3-08e7da1e2c23%22",
    "category": "Off Shoulder Dresses",
    "isLocked": false
  },
  {
    "id": 13,
    "imageUrl": "https://firebasestorage.googleapis.com/v0/b/facesnap-b2df8.firebasestorage.app/o/Dress%20Images%2FOff%20Shoulder%20Dresses%2Fo3.png?alt=media&token=1bb11286-e1bb-4869-afc5-7b01d00f67b5%22",
    "category": "Off Shoulder Dresses",
    "isLocked": false
  },
  {
    "id": 14,
    "imageUrl": "https://firebasestorage.googleapis.com/v0/b/facesnap-b2df8.firebasestorage.app/o/Dress%20Images%2FOff%20Shoulder%20Dresses%2Fo4.png?alt=media&token=4e16a6b3-6a17-4a25-8008-80c7a955829c%22",
    "category": "Off Shoulder Dresses",
    "isLocked": true
  },
  {
    "id": 15,
    "imageUrl": "https://firebasestorage.googleapis.com/v0/b/facesnap-b2df8.firebasestorage.app/o/Dress%20Images%2FOff%20Shoulder%20Dresses%2Fo5.png?alt=media&token=6fe95a42-bb67-426f-81dc-51080a2c7036%22",
    "category": "Off Shoulder Dresses",
    "isLocked": false
  },
  {
    "id": 16,
    "imageUrl": "https://firebasestorage.googleapis.com/v0/b/facesnap-b2df8.firebasestorage.app/o/Dress%20Images%2FShirt%20Dresses%2Fs1.png?alt=media&token=95c4f943-bda2-4ae9-a242-a94194b19ab8%22",
    "category": "Shirt Dresses",
    "isLocked": false
  },
  {
    "id": 17,
    "imageUrl": "https://firebasestorage.googleapis.com/v0/b/facesnap-b2df8.firebasestorage.app/o/Dress%20Images%2FShirt%20Dresses%2Fs2.png?alt=media&token=d1c9b961-4c80-4b20-adea-214b18fc9643%22",
    "category": "Shirt Dresses",
    "isLocked": false
  },
  {
    "id": 18,
    "imageUrl": "https://firebasestorage.googleapis.com/v0/b/facesnap-b2df8.firebasestorage.app/o/Dress%20Images%2FShirt%20Dresses%2Fs3.png?alt=media&token=b32a3dcf-cdbb-4c1b-a595-3b5d0bdc0b2b%22",
    "category": "Shirt Dresses",
    "isLocked": true
  },
  {
    "id": 19,
    "imageUrl": "https://firebasestorage.googleapis.com/v0/b/facesnap-b2df8.firebasestorage.app/o/Dress%20Images%2FShirt%20Dresses%2Fs4.png?alt=media&token=5486752c-d2c5-4d80-b9d0-483482635d6a%22",
    "category": "Shirt Dresses",
    "isLocked": false
  },
  {
    "id": 20,
    "imageUrl": "https://firebasestorage.googleapis.com/v0/b/facesnap-b2df8.firebasestorage.app/o/Dress%20Images%2FShirt%20Dresses%2Fs5.png?alt=media&token=8a7a0173-7bb4-48ed-93c0-319d67d1af36%22",
    "category": "Shirt Dresses",
    "isLocked": false
  },
  {
    "id": 21,
    "imageUrl": "https://firebasestorage.googleapis.com/v0/b/facesnap-b2df8.firebasestorage.app/o/Dress%20Images%2FWrap%20Dresses%2Fw1.png?alt=media&token=b0c3ff18-c998-44c6-961e-018c6c7573a7%22",
    "category": "Wrap Dresses",
    "isLocked": false
  },
  {
    "id": 22,
    "imageUrl": "https://firebasestorage.googleapis.com/v0/b/facesnap-b2df8.firebasestorage.app/o/Dress%20Images%2FWrap%20Dresses%2Fw2.png?alt=media&token=fbf10f7d-4c4f-415e-988b-006d24ac73d9%22",
    "category": "Wrap Dresses",
    "isLocked": false
  },
  {
    "id": 23,
    "imageUrl": "https://firebasestorage.googleapis.com/v0/b/facesnap-b2df8.firebasestorage.app/o/Dress%20Images%2FWrap%20Dresses%2Fw3.png?alt=media&token=d0498b1d-7e22-4aa2-9c2e-c986f780f33e%22",
    "category": "Wrap Dresses",
    "isLocked": false
  },
  {
    "id": 24,
    "imageUrl": "https://firebasestorage.googleapis.com/v0/b/facesnap-b2df8.firebasestorage.app/o/Dress%20Images%2FWrap%20Dresses%2Fw4.png?alt=media&token=8133af25-4162-4dcd-b2e7-f7b79a38131e%22",
    "category": "Wrap Dresses",
    "isLocked": true
  },
  {
    "id": 25,
    "imageUrl": "https://firebasestorage.googleapis.com/v0/b/facesnap-b2df8.firebasestorage.app/o/Dress%20Images%2FWrap%20Dresses%2Fw5.png?alt=media&token=69b8f60f-e203-4b0e-9901-338781a67258%22",
    "category": "Wrap Dresses",
    "isLocked": false
  }
]"""

dresses_data = json.loads(raw_json)

# 4. Processing
output_dresses = []
local_download_dir = "dresses"
os.makedirs(local_download_dir, exist_ok=True)

print("Starting download and upload process...")
for idx, item in enumerate(dresses_data):
    url = item["imageUrl"]
    # Clean the trailing quote encoded character if it exists
    if url.endswith('%22') or url.endswith('"'):
        url = url[:-3] if url.endswith('%22') else url[:-1]
    
    category = item["category"]
    
    # Organize into folders matching the category structure
    category_folder = os.path.join(local_download_dir, category)
    os.makedirs(category_folder, exist_ok=True)
    
    # Parse filename from url
    parsed_path = urllib.parse.urlparse(url).path
    filename = os.path.basename(urllib.parse.unquote(parsed_path))
    if not filename.endswith('.png'):
        filename = f"{filename}.png"
        
    local_path = os.path.join(category_folder, filename)
    
    print(f"[{idx+1}/{len(dresses_data)}] Downloading {filename} from {url}...")
    
    # Download
    response = requests.get(url, stream=True)
    if response.status_code == 200:
        with open(local_path, 'wb') as f:
            for chunk in response.iter_content(1024):
                f.write(chunk)
    else:
        print(f"Failed to download image {filename}. Status code: {response.status_code}")
        continue

    # Upload to Firebase Storage
    firebase_dest_path = f"Dress Images/{category}/{filename}"
    print(f"Uploading {filename} to Firebase Storage as '{firebase_dest_path}'...")
    
    blob = bucket.blob(firebase_dest_path)
    
    # Set public read access and token metadata
    download_token = str(uuid.uuid4())
    blob.metadata = {"firebaseStorageDownloadTokens": download_token}
    
    blob.upload_from_filename(local_path, content_type='image/png')
    
    # Generate download URL format
    encoded_path = urllib.parse.quote(firebase_dest_path, safe='')
    firebase_url = f"https://firebasestorage.googleapis.com/v0/b/{bucket_name}/o/{encoded_path}?alt=media&token={download_token}"
    
    new_item = {
        "id": item["id"],
        "imageUrl": firebase_url,
        "category": category,
        "isLocked": item["isLocked"]
    }
    output_dresses.append(new_item)

# 5. Output results
output_json_path = "dresses_updated.json"
with open(output_json_path, 'w', encoding='utf-8') as f:
    json.dump(output_dresses, f, indent=2)

print("\nSuccess!")
print(f"Downloaded local images folder path: {os.path.abspath(local_download_dir)}")
print(f"Generated new JSON file path: {os.path.abspath(output_json_path)}")
print("\nNew JSON Content:")
print(json.dumps(output_dresses, indent=2))

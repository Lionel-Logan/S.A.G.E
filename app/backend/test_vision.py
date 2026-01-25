import os
from google.cloud import vision

# 1. Point to your downloaded JSON file
# Make sure 'service_account.json' is the EXACT name of your file in the root folder
os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = "service_account.json"

def test_google_vision():
    try:
        print("🔍 Connecting to Google Vision API...")
        client = vision.ImageAnnotatorClient()

        # 2. Use a sample image from the internet (a road sign)
        image_uri = "https://cloud.google.com/vision/docs/images/sign_text.png"
        image = vision.Image()
        image.source.image_uri = image_uri

        print(f"📸 Analyzing image: {image_uri}")
        
        # 3. Request Text Detection
        response = client.text_detection(image=image)
        texts = response.text_annotations

        if response.error.message:
            print(f"❌ API Error: {response.error.message}")
            return

        # 4. Print the result
        if texts:
            print("\n✅ SUCCESS! Google Vision read this text:")
            print("------------------------------------------------")
            print(texts[0].description)
            print("------------------------------------------------")
        else:
            print("⚠️ Connected, but found no text.")

    except Exception as e:
        print(f"\n❌ FAILED. Could not connect.")
        print(f"Error details: {e}")
        print("\nTroubleshooting:")
        print("1. Check if 'service_account.json' is in this folder.")
        print("2. Open the file and check if it has 'project_id' and 'private_key'.")
        print("3. Make sure 'Cloud Vision API' is ENABLED in your Google Cloud Console.")

if __name__ == "__main__":
    test_google_vision()
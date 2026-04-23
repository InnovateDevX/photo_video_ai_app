# Trail AI

Trail AI is a premium, all-in-one AI-powered creative platform built with Flutter. It leverages state-of-the-art AI models to provide users with a wide range of image and video generation tools, wrapped in a beautiful, high-performance mobile application.

## 🚀 Key Features

### 🎬 AI Video Generation
Generate stunning videos from text or images using the latest models:
- **Seedance 1 & 2.0**: High-quality video synthesis.
- **Kling v2.5 Turbo & Standard**: Professional-grade video generation.
- **Google Veo 3.1 & Fast**: Rapid video creation.
- **Grok Imagine Video**: Creative video generation from X.ai.
- **MiniMax Video-01 & Hailuo**: Innovative video motion.
- **RunwayML Gen4 Turbo**: Industry-leading video AI.

### 🖼 AI Image Tools
- **Text-to-Image**: Create vivid images from text prompts.
- **AI Background**: Change or generate backgrounds for your photos.
- **AI Filter**: Apply artistic styles to your images.
- **AI Headshot**: Generate professional profile pictures.
- **AI Sticker**: Create custom stickers from text or images.
- **AI Logo**: Design unique logos for brands or personal use.

### 🛠 Professional Editing & Utilities
- **AI Restore & Upscale**: Fix low-quality images and enhance resolution.
- **Background Remove/Blur**: Instant background manipulation.
- **Outfit Change**: Try on different clothes using AI (Cloth Changer).
- **Pic Collage**: Create beautiful photo collages with custom templates.
- **Content Safety**: Integrated Azure Content Safety to ensure all generated content meets community standards.

## 🛠 Tech Stack

- **Framework**: [Flutter](https://flutter.dev/) (Dart)
- **Backend**: [Firebase](https://firebase.google.com/) (Auth, Firestore, Storage, Remote Config, Messaging, Crashlytics)
- **AI APIs**: [Replicate](https://replicate.com/) (Models), [Azure Content Safety](https://azure.microsoft.com/en-us/products/ai-services/ai-content-safety)
- **State Management**: [Flutter Bloc](https://pub.dev/packages/flutter_bloc) / Cubit
- **Monetization**: [RevenueCat](https://www.revenuecat.com/) (Subscriptions), [Google Mobile Ads](https://pub.dev/packages/google_mobile_ads)
- **Analytics**: [Facebook App Events](https://pub.dev/packages/facebook_app_events)

## 📦 Prerequisites

Before running the project, ensure you have:
- Flutter SDK (v3.10.1 or higher)
- A Firebase project set up.
- A Replicate API token.
- An Azure AI Content Safety resource key.
- A RevenueCat account and project.

## 🛠 Installation & Setup

1. **Clone the repository:**
   ```bash
   git clone https://github.com/usman2003/ai_app.git
   cd ai_app
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Configure Environment Variables:**
   Create a `.env` file in the root directory and add your Replicate token:
   ```env
   REPLICATE_API_TOKEN=your_replicate_token_here
   ```

4. **Firebase Setup:**
   - Add your `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) to the respective directories.
   - Run `flutterfire configure` if you have the FlutterFire CLI installed.

5. **Remote Config Setup:**
   Configure the following keys in your Firebase Remote Config console:
   - `replicate_auth_token`: Your Replicate API token.
   - `azure_content_safety_key`: Your Azure safety key.
   - `azure_content_safety_endpoint`: Your Azure endpoint.
   - `replicate_image_models`: JSON configuration for image models.
   - `replicate_video_models`: JSON configuration for video models.

6. **Run the app:**
   ```bash
   flutter run
   ```

## 🛡 Security Note

This project uses `.env` and Firebase Remote Config to manage sensitive API keys. Ensure that your `.env` file is never committed to version control (already added to `.gitignore`).

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

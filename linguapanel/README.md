# LinguaPanel

LinguaPanel is a Flutter-based mobile application that translates manga panels from images. It uses Firebase for authentication and storing translation metadata, and it connects to an external Python backend for the heavy image processing and translation pipeline.

## ✨ Features

- **Authentication**:
  - Sign in with Email & Password
  - Sign in with Google
  - Email verification for new accounts
  - Forgot password functionality
- **Manga Translation**:
  - Pick a manga panel image from the device gallery.
  - Send the image to the backend API for processing and translation.
  - View the original and translated images within the app.
- **Translation History**:
  - Automatically saves every translation.
  - View history in a dedicated screen with timestamps.
  - Delete unwanted history items.
  - Mark translations as favorites and view them in a dedicated Favorites screen.
- **Settings & Theme**:
  - Settings screen with appearance controls.
  - Light, Dark, and System Default theme options.
- **About & Feedback**:
  - About screen showing app name and version.
  - Quick guide on using the app.
  - Actions to rate the app and send feedback via email.
- **UI/UX**:
  - Clean, modern interface.
  - Full-screen image viewer for better detail.
  - Loading indicators and error handling for a smooth experience.

## 📥 Download

You can download the latest Android APK builds from the root project’s Releases page:

- [Download LinguaPanel APKs](https://github.com/FrxHaikalPlg/FinalProjectGDG/releases)

## 🏗️ Architecture (Frontend)

The Flutter project follows the **MVVM (Model-View-ViewModel)** architecture pattern, using the `provider` package for state management.

- **Model**: Represents the data structures (e.g., `TranslationHistory` in `features/history/model/`).
- **View**: The UI part of the application, which observes changes in the ViewModel (e.g., `HomeView`, `HistoryView`, `FavoritesView`, `SettingsView`, `AboutView`).
- **ViewModel**: Manages the state and business logic, interacting with services and updating the View (e.g., `HomeViewModel`, `HistoryViewModel`, `ThemeViewModel`, `AboutViewModel`).

## 🚀 Getting Started

To run this project locally, you will need to have Flutter installed and a Firebase project set up.

### Prerequisites

- Flutter SDK (version 3.x or higher)
- A Firebase project.
- A code editor like VS Code or Android Studio.

### Installation & Setup

1.  **Clone the repository:**
    ```sh
    git clone https://github.com/FrxHaikalPlg/FinalProjectGDG.git
    cd FinalProjectGDG/linguapanel
    ```

2.  **Set up Firebase:**
    *   Create a new project on the [Firebase Console](https://console.firebase.google.com/).
    *   Add an Android and/or iOS app to your Firebase project.
    *   Follow the instructions to download the `google-services.json` file for Android
    *   Place `google-services.json` in the `linguapanel/android/app/` directory.
    *   Place `GoogleService-Info.plist` in the `linguapanel/ios/Runner/` directory using Xcode.
    *   In your Firebase project, enable **Email/Password** and **Google** as sign-in methods in the **Authentication** service.
    *   Set up **Firebase Storage** to store the translation history.

3.  **Install dependencies:**
    Open your terminal in the `linguapanel` directory and run:
    ```sh
    flutter pub get
    ```

4.  **Run the app:**
    ```sh
    flutter run
    ```

## 📦 Key Dependencies

- `firebase_core`: For initializing the Firebase app.
- `firebase_auth`: For handling user authentication.
- `cloud_firestore`: For the translation history database.
- `firebase_storage`: For storing original and translated images.
- `google_sign_in`: For Google authentication.
- `image_picker`: For selecting images from the gallery.
- `provider`: For state management.
- `intl`: For date formatting in the history view.

For a complete list, see the `pubspec.yaml` file.

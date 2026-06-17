# Money Mate: Production Deployment Guide

This guide provides step-by-step instructions on configuring the **Money Mate** app for production deployment on Android and iOS.

---

## 🔑 1. Android Release Signing Configuration

To distribute your Android app on the Google Play Store, it must be signed with a production keystore. We have configured the build system to read these credentials securely from a local `key.properties` file that is excluded from Git.

### Step A: Generate a Keystore File
Open your terminal (PowerShell, Command Prompt, or Bash) and run the following command to generate a new Java keystore:

```bash
keytool -genkey -v -keystore android/key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias key
```

> [!IMPORTANT]
> - This command creates a keystore named `key.jks` inside your `android` folder.
> - Keep the passwords secure and make sure to back up your `key.jks` file. If you lose this keystore, you will be unable to push updates to existing Google Play listings.

### Step B: Create your local `key.properties`
1. Duplicate `android/key.properties.template` and rename the copy to `android/key.properties`.
2. Open `android/key.properties` and fill in the parameters with the passwords and alias you selected in Step A:

```properties
storePassword=your_keystore_password
keyPassword=your_key_password
keyAlias=key
storeFile=../key.jks
```

*Note: The relative path `../key.jks` is relative to the `android/app` directory, meaning `key.jks` resides inside the `android` root folder.*

---

## 🔥 2. Production Firebase Migration

Before building for production, ensure that your client configuration files point to your production Firebase console.

### Android
1. Download `google-services.json` from your production Firebase console.
2. Replace the development file located at:
   [google-services.json](file:///d:/sweta/Money_Mate/android/app/google-services.json)

### iOS
1. Download `GoogleService-Info.plist` from your production Firebase console.
2. Replace the development file located at:
   [GoogleService-Info.plist](file:///d:/sweta/Money_Mate/ios/Runner/GoogleService-Info.plist)

---

## 🚀 3. Compilation Commands

Once the signing configuration and production credentials are in place, run the following commands to compile optimized production bundles.

### Android
Generate a Google Play Asset Bundle (`.aab`):
```bash
flutter build appbundle --release
```
*(Alternatively, generate a standalone APK: `flutter build apk --release`)*

### iOS
Generate a release iOS package/archive:
```bash
flutter build ipa --release
```
*(Open the resulting build archive in Xcode to upload directly to TestFlight and App Store Connect)*

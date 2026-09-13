# mail-checker-app

Flutter app for Google Sign-In and Gmail inbox loading on Android.

## What is configured in this repository

- `google_sign_in` and `googleapis` are wired into the Flutter app.
- `android/app/build.gradle.kts` supports an optional local `android/key.properties` release signing file.
- `android/app/src/main/AndroidManifest.xml` includes the network permission required by the Android Gmail flow.
- The app accepts an optional OAuth web client ID through `--dart-define=GOOGLE_SERVER_CLIENT_ID=...` when your Google Sign-In setup requires it.

## 1. Pull the latest code and install dependencies

```bash
git pull origin "$(git branch --show-current)"
flutter pub get
```

If `flutter` is not on your `PATH`, open the project from a machine with the Flutter SDK installed and run the same command there.

## 2. Generate the Android SHA-1 fingerprint

Use either the default debug keystore or your own signing key.

### Debug keystore

```bash
keytool -list -v \
  -alias androiddebugkey \
  -keystore ~/.android/debug.keystore \
  -storepass android \
  -keypass android
```

If the file does not exist yet, create it by running the app once or generate it manually:

```bash
mkdir -p ~/.android
keytool -genkeypair -v \
  -storetype PKCS12 \
  -keystore ~/.android/debug.keystore \
  -alias androiddebugkey \
  -storepass android \
  -keypass android \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -dname "CN=Android Debug,O=Android,C=US"
```

### Release keystore

1. Create a keystore with `keytool -genkeypair ...`.
2. Copy `android/key.properties.example` to `android/key.properties`.
3. Fill in the keystore path, alias, and passwords.

`android/key.properties` is intentionally ignored by Git.

## 3. Configure Google Cloud and OAuth

1. Open [Google Cloud Console](https://console.cloud.google.com/).
2. Create or select a project.
3. Enable **Gmail API**.
4. Configure the OAuth consent screen.
5. Create an **Android OAuth client** with:
   - Package name: `com.example.mail_checker_app`
   - SHA-1 fingerprint: the value from the previous step
6. Create a **Web OAuth client** only if your Google Sign-In configuration requires a server client ID for Android sign-in.
7. If you created the Web OAuth client, pass it when running the app:

```bash
flutter run \
  --dart-define=GOOGLE_SERVER_CLIENT_ID=<your-web-client-id>
```

The implemented Gmail preview flow does not exchange a server auth code, so leaving `GOOGLE_SERVER_CLIENT_ID` unset is valid unless your Google Cloud setup specifically requires it.

## 4. Local Android files to add

### `android/key.properties`

Create this file locally from the example:

```properties
storeFile=/absolute/path/to/your-upload-keystore.jks
storePassword=replace-me
keyAlias=upload
keyPassword=replace-me
```

This app uses Google OAuth clients directly. A `google-services.json` file is not required unless you add Firebase or other Google Services integrations separately.

Modern Google Sign-In on Android does not require the deprecated `GET_ACCOUNTS` permission.

## 5. Testing on the Android emulator

1. Start an Android emulator image that includes Google Play services, then sign the emulator into a Google account.
2. Run the app:

```bash
flutter run
```

If your Android sign-in flow requires a Web OAuth client ID, use:

```bash
flutter run \
  --dart-define=GOOGLE_SERVER_CLIENT_ID=<your-web-client-id>
```

3. Verify that the login screen appears.
4. Tap **Sign in with Google**.
5. Approve the Gmail readonly scope.
6. Confirm that the inbox list loads.

## 6. Troubleshooting

- If sign-in fails immediately, confirm the Android package name and SHA-1 fingerprint match the Android OAuth client.
- If sign-in still fails for a project that requires a Web OAuth client, pass `--dart-define=GOOGLE_SERVER_CLIENT_ID=<your-web-client-id>` and confirm that client belongs to the same Google Cloud project.
- If Gmail loading fails after sign-in, verify that Gmail API is enabled in the selected Google Cloud project.
- If release signing is not configured yet, the Android build falls back to the debug signing config.

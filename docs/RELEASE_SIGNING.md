# Vokey Release Signing

The Android release keystore is intentionally not stored in this repository.

## Files and identity

- Application ID: `com.dev.vokey`
- Keystore file: `vokey-release.jks`
- Alias: `vokey`
- Store/key passwords: in the private `KEYSTORE_CREDENTIALS.txt` delivered with the signing kit.

Keep the JKS and its passwords backed up securely. Every future update of this same Play Store app must use the same signing identity. Never commit the JKS, passwords, or base64 contents to GitHub.

## Enable signed release builds in GitHub Actions

1. Open this repository on GitHub.
2. Go to **Settings → Secrets and variables → Actions → New repository secret**.
3. Add these four secrets:

| Secret name | Value |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | Base64 text of the entire `vokey-release.jks` file |
| `ANDROID_KEYSTORE_PASSWORD` | Store password from `KEYSTORE_CREDENTIALS.txt` |
| `ANDROID_KEY_PASSWORD` | Key password from `KEYSTORE_CREDENTIALS.txt` |
| `ANDROID_KEY_ALIAS` | `vokey` |

On macOS, copy the Base64 value to the clipboard with:

```bash
base64 -i vokey-release.jks | tr -d '\n' | pbcopy
```

Paste that value into the `ANDROID_KEYSTORE_BASE64` secret. Do not paste the Base64 string into a GitHub file or issue.

4. Open **Actions → Vokey Flutter checks → Run workflow** on `main`.
5. When the run succeeds, download the `vokey-release-apk` artifact for direct installation and `vokey-release-aab` for Google Play.

The workflow continues to run analysis, Dart tests, Kotlin tests and a debug build even before release secrets are configured. The signed release jobs are enabled only after all four secrets exist.

## Local release build

After the Android scaffold has been generated, place the JKS at `android/app/vokey-release.jks` and create `android/key.properties` from the private credentials. Then run:

```bash
flutter build apk --release
flutter build appbundle --release
```

The `android/key.properties` and JKS paths are git-ignored.

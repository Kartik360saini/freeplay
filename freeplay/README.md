# FreePlay

An Android music app (Flutter) that plays **audio only, with no ads**, and lets you search, download and organise music that artists have released for free.

## What it does

| Feature | Works without Spotify? |
| --- | --- |
| Search Jamendo (CC-licensed independent music) | Yes |
| Search the Internet Archive (Creative Commons audio and netlabels) | Yes |
| Stream in high quality (VBR MP3) | Yes |
| Download for offline play (MP3, FLAC or OGG, your choice) | Yes |
| Background playback and lock-screen controls | Yes |
| Playlists stored on your phone | Yes |
| Browse your Spotify playlists and liked songs, search Spotify, create and edit Spotify playlists | No, needs the Spotify setup below |
| Find free versions of Spotify songs / copy a Spotify playlist's free matches into a local playlist | No, needs Spotify and Jamendo |

What it does **not** do: play or download Spotify's own audio (Spotify's terms forbid it, and playback needs Premium anyway). Spotify songs open in the Spotify app. Mainstream chart music is rarely on Jamendo or the Archive, so those songs will usually have no free match.

## One-time setup

### 1. Jamendo (needed for search)
1. Go to https://devportal.jamendo.com and create a free app.
2. Copy its **Client ID**.
3. In the app: **Settings > Jamendo Client ID**, paste, tap the save icon.

### 2. Spotify (optional)
Since February 2026 Spotify only lets an app use its API if the **owner of the developer app has Premium**. Up to 5 other users can be added to the app.
1. Whoever has Premium creates an app at https://developer.spotify.com/dashboard.
2. Add the redirect URI `freeplay://callback`.
3. Under **User Management**, add the Spotify email of everyone who will log in (including you).
4. In the app: **Spotify tab > Connect Spotify**, paste the Client ID, and log in.

## Getting the APK onto your phone

### Easiest: let GitHub build it (no Android Studio needed)
1. Create a GitHub repository and push this folder to the `main` branch.
2. Open the repository's **Actions** tab. The "Build Android APK" workflow runs on every push (or press **Run workflow**).
3. When it finishes, open the run and download the **freeplay-apk** artifact (a zip containing `app-release.apk`).
4. Copy the APK to your phone and open it. Android will ask you to allow installs from that source.

### Or build on your computer
You need Flutter and Android Studio's SDK installed.
```bash
flutter create --platforms=android --org com.freeplay --project-name freeplay /tmp/scaffold
cp -r /tmp/scaffold/android ./android
python3 tool/patch_android.py .
flutter pub get
flutter build apk --release
# APK: build/app/outputs/flutter-apk/app-release.apk
```
(`tool/patch_android.py` sets the app name, permissions, the background-audio service and the Spotify login callback.)

## Notes
- Downloads are stored privately inside the app (Library > Downloads) and disappear if you uninstall it.
- The Spotify login uses PKCE, so no client secret is stored anywhere. Tokens are kept in the app's private storage.
- Check each track's licence before reusing it beyond personal listening (some Creative Commons licences forbid commercial use).
- The code was written without being compiled in the environment it was created in, so the first build may need small fixes. If the GitHub Action fails, open the failed step and send the error text.

#!/usr/bin/env python3
"""Patch the Android project that `flutter create` generates, for FreePlay.

Usage:  python3 tool/patch_android.py [project_dir]

It is safe to run more than once. It:
  * names the app "FreePlay"
  * adds the permissions needed for streaming, background playback and notifications
  * registers the background-audio service (just_audio_background)
  * registers the Spotify login callback (freeplay://callback)
  * makes MainActivity extend AudioServiceActivity
"""
import pathlib
import re
import sys

root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ".")
manifest_path = root / "android/app/src/main/AndroidManifest.xml"
if not manifest_path.exists():
    sys.exit(f"Missing {manifest_path}. Run `flutter create --platforms=android .` first.")

PERMISSIONS = [
    "INTERNET",
    "WAKE_LOCK",
    "FOREGROUND_SERVICE",
    "FOREGROUND_SERVICE_MEDIA_PLAYBACK",
    "POST_NOTIFICATIONS",
]

COMPONENTS = """
        <service
            android:name="com.ryanheise.audioservice.AudioService"
            android:foregroundServiceType="mediaPlayback"
            android:exported="true"
            tools:ignore="Instantiatable">
            <intent-filter>
                <action android:name="android.media.browse.MediaBrowserService" />
            </intent-filter>
        </service>
        <receiver
            android:name="com.ryanheise.audioservice.MediaButtonReceiver"
            android:exported="true"
            tools:ignore="Instantiatable">
            <intent-filter>
                <action android:name="android.intent.action.MEDIA_BUTTON" />
            </intent-filter>
        </receiver>
        <activity
            android:name="com.linusu.flutter_web_auth_2.CallbackActivity"
            android:exported="true">
            <intent-filter android:label="flutter_web_auth_2">
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                <data android:scheme="freeplay" />
            </intent-filter>
        </activity>
"""

CUSTOM_TABS_QUERY = """        <intent>
            <action android:name="android.support.customtabs.action.CustomTabsService" />
        </intent>
"""

text = manifest_path.read_text(encoding="utf-8")

if "com.ryanheise.audioservice.AudioService" not in text:
    if "xmlns:tools" not in text:
        text = text.replace(
            "<manifest ",
            '<manifest xmlns:tools="http://schemas.android.com/tools" ',
            1,
        )
    perms = "".join(
        f'    <uses-permission android:name="android.permission.{p}" />\n'
        for p in PERMISSIONS
        if f"android.permission.{p}" not in text
    )
    text = text.replace("<application", perms + "    <application", 1)
    text = re.sub(r'android:label="[^"]*"', 'android:label="FreePlay"', text, count=1)
    text = text.replace("</application>", COMPONENTS + "    </application>", 1)

    if "<queries>" in text:
        text = text.replace("<queries>", "<queries>\n" + CUSTOM_TABS_QUERY, 1)
    else:
        text = text.replace(
            "</manifest>", "    <queries>\n" + CUSTOM_TABS_QUERY + "    </queries>\n</manifest>", 1
        )
    manifest_path.write_text(text, encoding="utf-8")
    print("Patched AndroidManifest.xml")
else:
    print("AndroidManifest.xml already patched")

activities = list((root / "android/app/src/main").rglob("MainActivity.*"))
if not activities:
    sys.exit("Could not find MainActivity in android/app/src/main")
for path in activities:
    src = path.read_text(encoding="utf-8")
    if "AudioServiceActivity" in src:
        print(f"{path.name} already patched")
        continue
    src = src.replace(
        "import io.flutter.embedding.android.FlutterActivity",
        "import com.ryanheise.audioservice.AudioServiceActivity",
    )
    src = src.replace("FlutterActivity()", "AudioServiceActivity()")  # Kotlin
    src = src.replace("extends FlutterActivity", "extends AudioServiceActivity")  # Java
    path.write_text(src, encoding="utf-8")
    print(f"Patched {path.name}")

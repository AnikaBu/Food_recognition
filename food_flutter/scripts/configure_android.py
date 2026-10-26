#!/usr/bin/env python3
"""
Android configuration script for food_flutter.
Executes after `flutter create` to inject required permissions, cleartext traffic flag,
and release build configuration for GitHub Actions CI/CD.
"""
import os
import re
import subprocess
import sys

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ANDROID_DIR = os.path.join(BASE_DIR, "android")
APP_DIR = os.path.join(ANDROID_DIR, "app")
MANIFEST_PATH = os.path.join(APP_DIR, "src", "main", "AndroidManifest.xml")
GRADLE_GROOVY_PATH = os.path.join(APP_DIR, "build.gradle")
GRADLE_KTS_PATH = os.path.join(APP_DIR, "build.gradle.kts")


def configure_manifest():
    if not os.path.exists(MANIFEST_PATH):
        print(f"[-] Manifest not found at {MANIFEST_PATH}")
        return False

    with open(MANIFEST_PATH, "r", encoding="utf-8") as f:
        content = f.read()

    # Permissions to add
    permissions = [
        '<uses-permission android:name="android.permission.INTERNET"/>',
        '<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>',
        '<uses-permission android:name="android.permission.CAMERA"/>',
        '<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>',
        '<uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>',
    ]

    for perm in permissions:
        if perm not in content:
            content = content.replace("<manifest", f"{perm}\n<manifest", 1)

    # Enable cleartext traffic (for local HTTP servers) and update label
    if 'android:usesCleartextTraffic="true"' not in content:
        content = re.sub(
            r"<application(\s+)",
            r'<application\1android:usesCleartextTraffic="true"\1',
            content,
            count=1,
        )

    # Update app label to Food Recognition
    content = re.sub(
        r'android:label="[^"]*"',
        'android:label="Food Recognition"',
        content,
        count=1,
    )

    with open(MANIFEST_PATH, "w", encoding="utf-8") as f:
        f.write(content)

    print("[+] AndroidManifest.xml configured successfully.")
    return True


def configure_gradle():
    # Generate release keystore if not exists
    keystore_path = os.path.join(APP_DIR, "release.jks")
    if not os.path.exists(keystore_path):
        try:
            print("[*] Generating release keystore...")
            subprocess.run([
                "keytool", "-genkeypair", "-v",
                "-keystore", keystore_path,
                "-alias", "food_release",
                "-keyalg", "RSA", "-keysize", "2048", "-validity", "10000",
                "-storepass", "food_release_pass",
                "-keypass", "food_release_pass",
                "-dname", "CN=FoodRecognition, O=AnikaBu, C=RU"
            ], check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            print("[+] Release keystore generated.")
        except Exception as e:
            print(f"[!] Warning: Could not generate keystore with keytool: {e}. Will use debug signing.")

    # Configure Groovy build.gradle if present
    if os.path.exists(GRADLE_GROOVY_PATH):
        with open(GRADLE_GROOVY_PATH, "r", encoding="utf-8") as f:
            content = f.read()

        # Set minSdk to at least 21
        content = re.sub(
            r"minSdkVersion\s+(?:flutter\.minSdkVersion|\d+)",
            "minSdkVersion 21",
            content
        )
        content = re.sub(
            r"minSdk\s*=\s*(?:flutter\.minSdkVersion|\d+)",
            "minSdk = 21",
            content
        )

        # Ensure release signing uses either release.jks or debug signing
        if os.path.exists(keystore_path):
            signing_block = """
        release {
            keyAlias 'food_release'
            keyPassword 'food_release_pass'
            storeFile file('release.jks')
            storePassword 'food_release_pass'
        }
"""
            if "signingConfigs {" in content and "release {" not in content:
                content = content.replace("signingConfigs {", f"signingConfigs {{\n{signing_block}")
                content = content.replace(
                    "signingConfig = signingConfigs.debug",
                    "signingConfig = signingConfigs.release"
                )
                content = content.replace(
                    "signingConfig signingConfigs.debug",
                    "signingConfig signingConfigs.release"
                )

        with open(GRADLE_GROOVY_PATH, "w", encoding="utf-8") as f:
            f.write(content)
        print("[+] Groovy build.gradle configured successfully.")

    # Configure Kotlin DSL build.gradle.kts if present
    if os.path.exists(GRADLE_KTS_PATH):
        with open(GRADLE_KTS_PATH, "r", encoding="utf-8") as f:
            content = f.read()

        content = re.sub(r"minSdk\s*=\s*(?:flutter\.minSdkVersion|\d+)", "minSdk = 21", content)

        with open(GRADLE_KTS_PATH, "w", encoding="utf-8") as f:
            f.write(content)
        print("[+] Kotlin build.gradle.kts configured successfully.")


def main():
    print("[*] Configuring Android project for Food Recognition...")
    configure_manifest()
    configure_gradle()
    print("[+] Android configuration complete.")


if __name__ == "__main__":
    main()

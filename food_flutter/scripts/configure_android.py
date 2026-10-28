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
GRADLE_PROPERTIES_PATH = os.path.join(ANDROID_DIR, "gradle.properties")


def configure_manifest():
    if not os.path.exists(MANIFEST_PATH):
        print(f"[-] Manifest not found at {MANIFEST_PATH}")
        return False

    with open(MANIFEST_PATH, "r", encoding="utf-8") as f:
        content = f.read()

    # Permissions to add inside <manifest> before <application>
    permissions = [
        '<uses-permission android:name="android.permission.INTERNET"/>',
        '<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>',
        '<uses-permission android:name="android.permission.CAMERA"/>',
        '<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>',
        '<uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>',
        '<uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES"/>',
        '<uses-permission android:name="android.permission.QUERY_ALL_PACKAGES"/>',
    ]

    new_perms = [p for p in permissions if p not in content]
    if new_perms:
        content = content.replace(
            "<application",
            "\n    ".join(new_perms) + "\n\n    <application",
            1
        )

    # Queries block for url_launcher on Android 11+
    if "<queries>" not in content:
        queries_block = """    <queries>
        <intent>
            <action android:name="android.intent.action.VIEW" />
            <data android:scheme="https" />
        </intent>
        <intent>
            <action android:name="android.intent.action.VIEW" />
            <data android:scheme="http" />
        </intent>
    </queries>\n\n    """
        content = content.replace("<application", queries_block + "<application", 1)


    # Enable cleartext traffic (for local HTTP servers) and update label
    if 'android:usesCleartextTraffic="true"' not in content:
        content = re.sub(
            r"<application(\s+)",
            r'<application\1android:usesCleartextTraffic="true"\1',
            content,
            count=1,
        )

    # Update app label to MyFoodDiary
    content = re.sub(
        r'android:label="[^"]*"',
        'android:label="MyFoodDiary"',
        content,
        count=1,
    )

    # Validate XML integrity
    import xml.etree.ElementTree as ET
    try:
        ET.fromstring(content)
    except Exception as err:
        print(f"[-] XML validation failed: {err}")
        return False

    with open(MANIFEST_PATH, "w", encoding="utf-8") as f:
        f.write(content)

    print("[+] AndroidManifest.xml configured successfully.")
    return True


def configure_gradle():
    # Setup persistent release keystore
    keystore_path = os.path.join(APP_DIR, "release.jks")
    b64_keystore_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "release_keystore.b64")

    if os.path.exists(b64_keystore_path):
        try:
            import base64
            print("[*] Restoring persistent release keystore from release_keystore.b64...")
            with open(b64_keystore_path, "r", encoding="utf-8") as f:
                data = base64.b64decode(f.read().strip())
            with open(keystore_path, "wb") as f:
                f.write(data)
            print("[+] Persistent release keystore restored successfully.")
        except Exception as e:
            print(f"[!] Warning: Could not restore keystore from b64: {e}")

    if not os.path.exists(keystore_path):
        try:
            print("[*] Generating fallback release keystore...")
            subprocess.run([
                "keytool", "-genkeypair", "-v",
                "-keystore", keystore_path,
                "-alias", "food_release",
                "-keyalg", "RSA", "-keysize", "2048", "-validity", "10000",
                "-storepass", "food_release_pass",
                "-keypass", "food_release_pass",
                "-dname", "CN=MyFoodDiary, O=AnikaBu, C=RU"
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


def configure_icons():
    icon_src = os.path.join(BASE_DIR, "assets", "icon", "app_icon.png")
    if not os.path.exists(icon_src):
        print("[-] Master icon not found, skipping icon generation.")
        return

    try:
        from PIL import Image, ImageDraw
        import shutil

        master = Image.open(icon_src).convert("RGBA")
        res_dir = os.path.join(APP_DIR, "src", "main", "res")
        sizes = {
            "mipmap-mdpi": 48,
            "mipmap-hdpi": 72,
            "mipmap-xhdpi": 96,
            "mipmap-xxhdpi": 144,
            "mipmap-xxxhdpi": 192,
        }

        def create_round_icon(img, size):
            mask = Image.new("L", (size * 4, size * 4), 0)
            draw = ImageDraw.Draw(mask)
            draw.ellipse((0, 0, size * 4, size * 4), fill=255)
            mask = mask.resize((size, size), Image.Resampling.LANCZOS)
            rounded = Image.new("RGBA", (size, size), (0, 0, 0, 0))
            rounded.paste(img, (0, 0), mask=mask)
            return rounded

        for folder, size in sizes.items():
            target_folder = os.path.join(res_dir, folder)
            os.makedirs(target_folder, exist_ok=True)

            resized = master.resize((size, size), Image.Resampling.LANCZOS)
            resized.save(os.path.join(target_folder, "ic_launcher.png"), "PNG")

            rounded = create_round_icon(resized, size)
            rounded.save(os.path.join(target_folder, "ic_launcher_round.png"), "PNG")

        # Remove adaptive icon xml if present so launcher uses our PNG directly
        anydpi_dir = os.path.join(res_dir, "mipmap-anydpi-v26")
        if os.path.exists(anydpi_dir):
            shutil.rmtree(anydpi_dir)
            print("[+] Removed adaptive icon xml to use direct high-res icons.")

        print("[+] All Android launcher icons configured successfully.")
    except Exception as e:
        print(f"[!] Warning: Icon generation error: {e}")


def configure_gradle_properties():
    if not os.path.exists(ANDROID_DIR):
        return

    lines = []
    if os.path.exists(GRADLE_PROPERTIES_PATH):
        with open(GRADLE_PROPERTIES_PATH, "r", encoding="utf-8") as f:
            lines = f.readlines()

    props_to_set = {
        "android.newDsl": "false",
        "android.builtInKotlin": "false",
    }

    new_lines = []
    found_keys = set()
    for line in lines:
        stripped = line.strip()
        matched = False
        for key, val in props_to_set.items():
            if stripped.startswith(f"{key}=") or stripped.startswith(f"{key} ="):
                new_lines.append(f"{key}={val}\n")
                found_keys.add(key)
                matched = True
                break
        if not matched:
            new_lines.append(line)

    for key, val in props_to_set.items():
        if key not in found_keys:
            new_lines.append(f"{key}={val}\n")

    with open(GRADLE_PROPERTIES_PATH, "w", encoding="utf-8") as f:
        f.writelines(new_lines)
    print("[+] gradle.properties configured successfully (android.newDsl=false).")


def sync_version():
    pubspec_path = os.path.join(BASE_DIR, "pubspec.yaml")
    service_path = os.path.join(BASE_DIR, "lib", "services", "update_service.dart")
    if not os.path.exists(pubspec_path) or not os.path.exists(service_path):
        return

    with open(pubspec_path, "r", encoding="utf-8") as f:
        pub_content = f.read()

    match = re.search(r"^version:\s*([0-9]+\.[0-9]+\.[0-9]+)", pub_content, re.MULTILINE)
    if not match:
        return

    ver = match.group(1)
    with open(service_path, "r", encoding="utf-8") as f:
        service_content = f.read()

    new_content = re.sub(
        r"static const String currentVersion = '[^']+';",
        f"static const String currentVersion = '{ver}';",
        service_content,
        count=1
    )

    if new_content != service_content:
        with open(service_path, "w", encoding="utf-8") as f:
            f.write(new_content)
        print(f"[+] Synchronized currentVersion = '{ver}' into update_service.dart")
    else:
        print(f"[+] update_service.dart already at version '{ver}'.")


def main():
    print("[*] Configuring Android project for MyFoodDiary...")
    sync_version()
    configure_manifest()
    configure_gradle()
    configure_gradle_properties()
    configure_icons()
    print("[+] Android configuration complete.")


if __name__ == "__main__":
    main()


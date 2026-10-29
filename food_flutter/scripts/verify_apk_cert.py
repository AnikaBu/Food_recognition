#!/usr/bin/env python3
"""
Verifies that the built Android APK is signed with the persistent release certificate (release.jks).
Ensures CI/CD will never release an APK signed with a temporary debug key.
"""
import hashlib
import os
import struct
import sys

# SHA-256 fingerprint of the persistent release certificate in release_keystore.b64
EXPECTED_SHA256 = "70928ca63835402b8987ab58302dfdf578a1f911a11fff4a30f8a4fcd4b4c8e8"


def extract_v2_cert(apk_path: str) -> bytes:
    with open(apk_path, "rb") as f:
        data = f.read()

    eocd_idx = data.rfind(b"\x50\x4b\x05\x06")
    if eocd_idx == -1:
        raise ValueError(f"File {apk_path} is not a valid zip/APK archive")

    cd_offset = struct.unpack("<I", data[eocd_idx + 16 : eocd_idx + 20])[0]
    magic = data[cd_offset - 16 : cd_offset]
    if magic != b"APK Sig Block 42":
        raise ValueError("No APK Signature Scheme Block found in APK")

    block_size = struct.unpack("<Q", data[cd_offset - 24 : cd_offset - 16])[0]
    sig_block = data[cd_offset - 8 - block_size : cd_offset]

    offset = 8
    while offset < len(sig_block) - 24:
        length = struct.unpack("<Q", sig_block[offset : offset + 8])[0]
        entry_id = struct.unpack("<I", sig_block[offset + 8 : offset + 12])[0]
        val = sig_block[offset + 12 : offset + 8 + length]

        if entry_id == 0x7109871A:  # APK Signature Scheme v2
            signers_len = struct.unpack("<I", val[:4])[0]
            signer_bytes = val[4 : 4 + signers_len]
            signer_len = struct.unpack("<I", signer_bytes[:4])[0]
            signer = signer_bytes[4 : 4 + signer_len]

            signed_data_len = struct.unpack("<I", signer[:4])[0]
            signed_data = signer[4 : 4 + signed_data_len]

            pos = 0
            digests_len = struct.unpack("<I", signed_data[pos : pos + 4])[0]
            pos += 4 + digests_len

            certs_len = struct.unpack("<I", signed_data[pos : pos + 4])[0]
            pos += 4

            cert_len = struct.unpack("<I", signed_data[pos : pos + 4])[0]
            pos += 4
            return signed_data[pos : pos + cert_len]

        offset += 8 + length

    raise ValueError("No APK Signature Scheme v2 found in APK")


def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <path_to_apk>")
        sys.exit(1)

    apk_path = sys.argv[1]
    if not os.path.exists(apk_path):
        print(f"[-] APK file not found at: {apk_path}")
        sys.exit(1)

    print(f"[*] Verifying certificate signature for: {apk_path} ...")
    try:
        cert_der = extract_v2_cert(apk_path)
    except Exception as e:
        print(f"[-] Failed to extract certificate from APK: {e}")
        sys.exit(1)

    actual_sha256 = hashlib.sha256(cert_der).hexdigest().lower()
    formatted_actual = ":".join(actual_sha256[i : i + 2].upper() for i in range(0, len(actual_sha256), 2))
    formatted_expected = ":".join(EXPECTED_SHA256[i : i + 2].upper() for i in range(0, len(EXPECTED_SHA256), 2))

    print(f"[*] Certificate SHA-256 fingerprint: {formatted_actual}")

    if actual_sha256 != EXPECTED_SHA256:
        print("[-] ERROR: APK is NOT signed with the persistent release certificate!")
        print(f"    Expected: {formatted_expected}")
        print(f"    Actual:   {formatted_actual}")
        print("[-] This would cause INSTALL_FAILED_UPDATE_INCOMPATIBLE on devices. Failing build!")
        sys.exit(1)

    print("[+] SUCCESS: APK is verified and signed with the permanent MyFoodDiary release certificate!")
    sys.exit(0)


if __name__ == "__main__":
    main()

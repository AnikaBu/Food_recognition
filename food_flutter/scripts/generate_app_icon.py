#!/usr/bin/env python3
"""
Generate full-bleed 1024x1024 master icon and PWA icons.
Takes source icon illustration, eliminates borders and margins,
inpaints seamless gradient into the corners, and exports full-bleed assets.
"""
import os
import sys
import numpy as np
from PIL import Image
from scipy.ndimage import binary_erosion, distance_transform_edt, gaussian_filter

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
FOOD_FLUTTER_DIR = os.path.dirname(SCRIPT_DIR)
REPO_ROOT = os.path.dirname(FOOD_FLUTTER_DIR)


def generate_full_bleed_icon(source_path: str, output_1024_path: str, crop_size: int = 680):
    if not os.path.exists(source_path):
        raise FileNotFoundError(f"Source image not found: {source_path}")

    img = Image.open(source_path).convert("RGB")
    arr = np.array(img)

    # 1. Segment squircle by flood-filling grey mockup background from borders
    h, w, _ = arr.shape
    # Grey background check (saturation < 20 and brightness > 150)
    max_c = arr.max(axis=-1).astype(float)
    min_c = arr.min(axis=-1).astype(float)
    delta = max_c - min_c
    sat = np.zeros_like(max_c)
    mask_nz = (max_c > 0)
    sat[mask_nz] = (delta[mask_nz] / max_c[mask_nz]) * 100.0

    is_bg = (sat < 20) & (max_c > 140)

    # BFS from borders to find outer mockup background
    from collections import deque
    bg_mask = np.zeros((h, w), dtype=bool)
    q = deque()
    for x in range(w):
        if is_bg[0, x]:
            bg_mask[0, x] = True
            q.append((0, x))
        if is_bg[h - 1, x]:
            bg_mask[h - 1, x] = True
            q.append((h - 1, x))
    for y in range(h):
        if is_bg[y, 0]:
            bg_mask[y, 0] = True
            q.append((y, 0))
        if is_bg[y, w - 1]:
            bg_mask[y, w - 1] = True
            q.append((y, w - 1))

    while q:
        cy, cx = q.popleft()
        for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            ny, nx = cy + dy, cx + dx
            if 0 <= ny < h and 0 <= nx < w and not bg_mask[ny, nx] and is_bg[ny, nx]:
                bg_mask[ny, nx] = True
                q.append((ny, nx))

    squircle_solid = ~bg_mask

    # 2. Crop centered around the squircle
    S = crop_size
    x0, y0 = int(517 - S / 2), int(517 - S / 2)
    crop_rgb = arr[y0:y0 + S, x0:x0 + S].astype(np.float32)
    crop_solid = squircle_solid[y0:y0 + S, x0:x0 + S]

    # 3. Erode solid mask by 12 iterations to eliminate edge bevel/rim
    eroded_solid = binary_erosion(crop_solid, iterations=12)

    # 4. Seamless distance-transform inpainting to fill outer corners
    indices = distance_transform_edt(~eroded_solid, return_indices=True)[1]
    extrap = crop_rgb[indices[0], indices[1]]
    blurred_extrap = gaussian_filter(extrap, sigma=(8, 8, 0))

    dist = distance_transform_edt(eroded_solid)
    weight = np.clip(dist / 12.0, 0.0, 1.0)[:, :, np.newaxis]
    final_crop = crop_rgb * weight + blurred_extrap * (1.0 - weight)

    final_img = Image.fromarray(np.clip(final_crop, 0, 255).astype(np.uint8), mode="RGB")
    master_1024 = final_img.resize((1024, 1024), Image.Resampling.LANCZOS)

    os.makedirs(os.path.dirname(output_1024_path), exist_ok=True)
    master_1024.save(output_1024_path, "PNG")
    print(f"[+] Master 1024x1024 icon saved to {output_1024_path}")

    # Also save PWA icons
    pwa_512 = master_1024.resize((512, 512), Image.Resampling.LANCZOS)
    pwa_192 = master_1024.resize((192, 192), Image.Resampling.LANCZOS)

    pwa_dir = os.path.join(REPO_ROOT, "frontend", "icons")
    os.makedirs(pwa_dir, exist_ok=True)
    pwa_512.save(os.path.join(pwa_dir, "icon-512.png"), "PNG")
    pwa_192.save(os.path.join(pwa_dir, "icon-192.png"), "PNG")
    print(f"[+] PWA icons (512x512, 192x192) saved to {pwa_dir}")


if __name__ == "__main__":
    src = sys.argv[1] if len(sys.argv) > 1 else "/home/buravchik/.gemini/antigravity/brain/f36130dd-88ea-4de5-b41b-65802f6ac327/.user_uploaded/media_1793723635824.jpg"
    out = os.path.join(FOOD_FLUTTER_DIR, "assets", "icon", "app_icon.png")
    generate_full_bleed_icon(src, out)

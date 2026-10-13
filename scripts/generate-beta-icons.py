import os
from PIL import Image, ImageDraw, ImageFont

densities = {
    'mdpi': (48, 108),
    'hdpi': (72, 162),
    'xhdpi': (96, 216),
    'xxhdpi': (144, 324),
    'xxxhdpi': (192, 432),
}

main_res = '/opt/data/Fireflytonic/android/app/src/main/res'
beta_res = '/opt/data/Fireflytonic/android/app/src/beta/res'
os.makedirs(f'{beta_res}/values', exist_ok=True)

with open(f'{beta_res}/values/colors.xml', 'w') as f:
    f.write('''<?xml version="1.0" encoding="utf-8"?>\n<resources>\n    <color name="ic_launcher_background">#1e293b</color>\n</resources>\n''')

font_path = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'

for density, (launcher_size, fg_size) in densities.items():
    out_dir = f'{beta_res}/mipmap-{density}'
    os.makedirs(out_dir, exist_ok=True)

    fg_src_path = f'{main_res}/mipmap-{density}/ic_launcher_foreground.png'
    if os.path.exists(fg_src_path):
        fg_img = Image.open(fg_src_path).convert('RGBA')
        W, H = fg_img.size
        draw = ImageDraw.Draw(fg_img)

        font_size = max(10, int(H * 0.08))
        font = ImageFont.truetype(font_path, font_size)
        text = 'BETA'
        bbox = draw.textbbox((0, 0), text, font=font)
        text_w = bbox[2] - bbox[0]
        text_h = bbox[3] - bbox[1]

        pad_x = int(font_size * 0.4)
        pad_y = int(font_size * 0.2)
        badge_w = text_w + pad_x * 2
        badge_h = text_h + pad_y * 2

        badge_cx = W / 2
        badge_cy = H * 0.74

        bx0 = badge_cx - badge_w / 2
        by0 = badge_cy - badge_h / 2
        bx1 = badge_cx + badge_w / 2
        by1 = badge_cy + badge_h / 2

        corner_r = badge_h / 2
        draw.rounded_rectangle([bx0, by0, bx1, by1], radius=corner_r, fill=(245, 158, 11, 255), outline=(255, 255, 255, 255), width=max(1, int(H * 0.008)))

        tx = bx0 + (badge_w - text_w) / 2 - bbox[0]
        ty = by0 + (badge_h - text_h) / 2 - bbox[1]
        draw.text((tx, ty), text, font=font, fill=(0, 0, 0, 255))
        fg_img.save(f'{out_dir}/ic_launcher_foreground.png')

    l_src_path = f'{main_res}/mipmap-{density}/ic_launcher.png'
    if os.path.exists(l_src_path):
        l_img = Image.open(l_src_path).convert('RGBA')
        W, H = l_img.size
        draw = ImageDraw.Draw(l_img)

        font_size = max(9, int(H * 0.16))
        font = ImageFont.truetype(font_path, font_size)
        text = 'BETA'
        bbox = draw.textbbox((0, 0), text, font=font)
        text_w = bbox[2] - bbox[0]
        text_h = bbox[3] - bbox[1]

        pad_x = int(font_size * 0.35)
        pad_y = int(font_size * 0.15)
        badge_w = text_w + pad_x * 2
        badge_h = text_h + pad_y * 2

        bx0 = W - badge_w - 2
        by0 = H - badge_h - 2
        bx1 = W - 2
        by1 = H - 2

        corner_r = max(2, int(badge_h * 0.25))
        draw.rounded_rectangle([bx0, by0, bx1, by1], radius=corner_r, fill=(245, 158, 11, 255), outline=(255, 255, 255, 255), width=max(1, int(H * 0.015)))

        tx = bx0 + (badge_w - text_w) / 2 - bbox[0]
        ty = by0 + (badge_h - text_h) / 2 - bbox[1]
        draw.text((tx, ty), text, font=font, fill=(0, 0, 0, 255))
        l_img.save(f'{out_dir}/ic_launcher.png')

print('Beta icons generated successfully!')

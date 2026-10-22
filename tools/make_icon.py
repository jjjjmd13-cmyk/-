"""Renders the game icon (matches icon.svg) to icon.png and icon.ico."""
from PIL import Image, ImageDraw

S = 1024
img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
d = ImageDraw.Draw(img)
k = S / 256
d.rounded_rectangle([0, 0, S - 1, S - 1], radius=int(40 * k), fill=(22, 12, 16, 255))
d.ellipse([32 * k, 32 * k, 224 * k, 224 * k], outline=(201, 164, 92, 255), width=int(10 * k))
d.polygon([(128 * k, 30 * k), (146 * k, 150 * k), (128 * k, 200 * k), (110 * k, 150 * k)],
          fill=(217, 221, 227, 255), outline=(74, 58, 42, 255))
d.rounded_rectangle([80 * k, 146 * k, 176 * k, 162 * k], radius=int(6 * k), fill=(201, 164, 92, 255))
d.rounded_rectangle([120 * k, 160 * k, 136 * k, 210 * k], radius=int(5 * k), fill=(122, 26, 36, 255))
d.ellipse([117 * k, 207 * k, 139 * k, 229 * k], fill=(201, 164, 92, 255))
img = img.resize((512, 512), Image.LANCZOS)
img.save("assets/icon/icon.png")
img.save("assets/icon/icon.ico", sizes=[(16, 16), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
print("ok")

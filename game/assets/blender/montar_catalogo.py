import sys, os, csv
from PIL import Image, ImageDraw, ImageFont
base = sys.argv[1]; out = sys.argv[2]
rows = list(csv.DictReader(open(os.path.join(base, "catalogo.csv"), encoding="utf-8")))
T, cols, lab = 300, 6, 34
n = len(rows); lin = (n + cols - 1) // cols
img = Image.new("RGB", (cols*T, lin*(T+lab)), (245, 243, 238))
d = ImageDraw.Draw(img)
try: f = ImageFont.load_default(size=20)
except TypeError: f = ImageFont.load_default()
for i, r in enumerate(rows):
    th = Image.open(os.path.join(base, "previews", r["nome"] + ".png")).convert("RGB").resize((T, T))
    x, y = (i % cols)*T, (i//cols)*(T+lab)
    img.paste(th, (x, y))
    d.text((x+8, y+T+6), r["nome"], fill=(30,30,30), font=f)
img.save(out)

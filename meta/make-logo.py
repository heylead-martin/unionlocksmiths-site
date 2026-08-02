from PIL import Image, ImageDraw
import math

SRC = "/home/user/unionlocksmiths-site/assets/wahluen-logo.jpeg"
DST = "/home/user/unionlocksmiths-site/assets/wahluen-logo.png"
im = Image.open(SRC).convert("RGB")
w, h = im.size
px = im.load()

def lum(p): return 0.299*p[0] + 0.587*p[1] + 0.114*p[2]

pts = [(x, y) for y in range(0, h, 2) for x in range(0, w, 2) if lum(px[x, y]) < 90]

# Robust circle fit. A bounding box is skewed by dark speckles in the paper
# texture; centroid plus a high-percentile radius ignores them.
cx = sum(p[0] for p in pts) / len(pts)
cy = sum(p[1] for p in pts) / len(pts)
d = sorted(math.hypot(x - cx, y - cy) for x, y in pts)
r_fit = d[int(len(d) * 0.995)]

# Walk outward to find where the black ring actually ends, rather than
# trusting the fit: masking at r_fit left a ring of background yellow
# showing round the edge.
def ring_edge(r_start):
    last_dark = r_start
    rr = r_start * 0.94
    while rr < r_start * 1.02:
        dark = 0
        for i in range(0, 360, 5):
            a = math.radians(i)
            x, y = int(cx + rr*math.cos(a)), int(cy + rr*math.sin(a))
            if 0 <= x < w and 0 <= y < h and lum(px[x, y]) < 110: dark += 1
        if dark >= 60: last_dark = rr      # still mostly ring
        rr += 1
    return last_dark

r = ring_edge(r_fit)
print(f"fit radius {r_fit:.0f} -> ring outer edge {r:.0f}")

S = 4
side = int(2 * r)
mask = Image.new("L", (side*S, side*S), 0)
ImageDraw.Draw(mask).ellipse([0, 0, side*S-1, side*S-1], fill=255)
mask = mask.resize((side, side), Image.LANCZOS)

crop = im.crop((int(cx-r), int(cy-r), int(cx-r)+side, int(cy-r)+side)).convert("RGBA")
crop.putalpha(mask)
out = crop.resize((704, 704), Image.LANCZOS)
out.save(DST, "PNG", optimize=True)
print("wrote", out.size)

# verify: no yellow surviving near the edge
p = out.load(); c = 352
for frac in (0.95, 0.98, 0.99, 1.0):
    rr = c*frac - 0.5; sam = []
    for i in range(0, 360, 15):
        a = math.radians(i); x, y = int(c+rr*math.cos(a)), int(c+rr*math.sin(a))
        if 0 <= x < 704 and 0 <= y < 704: sam.append(p[x, y])
    yel = sum(1 for s in sam if s[3] > 128 and s[0] > 180 and s[1] > 130 and s[2] < 90)
    print(f"  r={frac:4.2f}  yellow-ish: {yel}/{len(sam)}")

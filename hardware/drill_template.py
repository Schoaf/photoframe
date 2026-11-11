"""Writes drill_template.pdf: 1:1 drilling template for the back panel.

Values match tablet_frame.scad (see its ECHO output). All sizes in mm, seen
from the BACK of the frame. Print at 100 % ("Tatsächliche Größe").
"""

from pathlib import Path

PT = 72 / 25.4
PAGE_W, PAGE_H = 210, 297

# From the right inner edge / top, seen from the back.
PLUNGERS = [(53.65, "Power"), (74.65, "Lauter/Leiser"), (85.65, "Lauter/Leiser")]
PLUNGER_TOP = 12.35
PLUNGER_HOLE = 5.5
USB = (2.25, 19.6, 91, 109)
# From the left inner edge / top, seen from the back.
SPEAKERS = [(17.6, 25.6, 44.35, 63.35), (17.6, 25.6, 136.65, 155.65)]
SPEAKER_HOLE = 5


class Page:
    def __init__(self):
        self.ops = []

    def _p(self, x, y):
        return f"{x * PT:.2f} {(PAGE_H - y) * PT:.2f}"

    def width(self, mm):
        self.ops.append(f"{mm * PT:.2f} w")

    def line(self, x1, y1, x2, y2):
        self.ops.append(f"{self._p(x1, y1)} m {self._p(x2, y2)} l S")

    def rect(self, x1, y1, x2, y2):
        self.ops.append(
            f"{x1 * PT:.2f} {(PAGE_H - y2) * PT:.2f} {(x2 - x1) * PT:.2f} {(y2 - y1) * PT:.2f} re S"
        )

    def circle(self, x, y, d):
        r, k = d / 2, 0.5523 * d / 2
        pts = [
            (x + r, y), (x + r, y + k), (x + k, y + r), (x, y + r),
            (x - k, y + r), (x - r, y + k), (x - r, y),
            (x - r, y - k), (x - k, y - r), (x, y - r),
            (x + k, y - r), (x + r, y - k), (x + r, y),
        ]
        out = [f"{self._p(*pts[0])} m"]
        for i in range(1, 13, 3):
            out.append(f"{self._p(*pts[i])} {self._p(*pts[i + 1])} {self._p(*pts[i + 2])} c")
        self.ops.append(" ".join(out) + " S")

    def hole(self, x, y, d):
        self.circle(x, y, d)
        self.line(x - d, y, x + d, y)
        self.line(x, y - d, x, y + d)

    def text(self, x, y, s, size=9):
        s = s.replace("\\", "\\\\").replace("(", "\\(").replace(")", "\\)")
        self.ops.append(f"BT /F1 {size} Tf {self._p(x, y)} Td ({s}) Tj ET")

    def scale_bar(self, x, y):
        self.width(0.4)
        self.line(x, y, x + 100, y)
        for i in range(0, 101, 10):
            self.line(x + i, y - (3 if i % 50 == 0 else 1.5), x + i, y)
        self.text(x, y + 5, "Kontrolle: diese Linie muss genau 100 mm lang sein.")


def right_corner():
    page = Page()
    cx, cy = 185, 25  # inner corner top right
    page.text(20, 12, "Bohrschablone 1/2 - Rückwand von HINTEN, Ecke OBEN RECHTS", 11)
    page.width(0.8)
    page.line(cx - 150, cy, cx, cy)
    page.line(cx, cy, cx, cy + 130)
    page.text(cx - 150, cy - 2, "Oberkante Rückwand - hier anlegen")
    page.text(cx - 40, cy + 135, "Rechte Kante - hier anlegen")
    page.width(0.3)
    for i, (dx, label) in enumerate(PLUNGERS):
        x, y = cx - dx, cy + PLUNGER_TOP
        page.hole(x, y, PLUNGER_HOLE)
        page.text(x - 6, y + 9 + (i % 2) * 5, label, 7)
    page.text(cx - 95, cy + 32, f"3 Löcher {PLUNGER_HOLE} mm für die Druckstifte")
    r1, r2, t1, t2 = USB
    page.rect(cx - r2, cy + t1, cx - r1, cy + t2)
    page.text(cx - 70, cy + (t1 + t2) / 2, "USB-Kabel: ausschneiden ->")
    page.scale_bar(30, 250)
    return page


def left_corner():
    page = Page()
    cx, cy = 25, 25  # inner corner top left
    page.text(20, 12, "Bohrschablone 2/2 - Rückwand von HINTEN, Ecke OBEN LINKS", 11)
    page.width(0.8)
    page.line(cx, cy, cx + 150, cy)
    page.line(cx, cy, cx, cy + 175)
    page.text(cx + 40, cy - 2, "Oberkante Rückwand - hier anlegen")
    page.text(cx - 2, cy + 180, "Linke Kante")
    page.width(0.3)
    for l1, l2, t1, t2 in SPEAKERS:
        page.rect(cx + l1, cy + t1, cx + l2, cy + t2)
        for i in range(3):
            page.hole(cx + (l1 + l2) / 2, cy + t1 + 4 + i * (t2 - t1 - 8) / 2, SPEAKER_HOLE)
        page.text(cx + l2 + 4, cy + (t1 + t2) / 2, f"Lautsprecher: Löcher {SPEAKER_HOLE} mm (optional, lauter)")
    page.scale_bar(30, 250)
    return page


def write_pdf(pages, path):
    objs = ["<< /Type /Catalog /Pages 2 0 R >>", None,
            "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>"]
    kids = []
    for page in pages:
        stream = "\n".join(page.ops).encode("cp1252")
        objs.append(f"<< /Length {len(stream)} >>\nstream\n".encode("cp1252") + stream + b"\nendstream")
        content = len(objs)
        objs.append(
            f"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 {PAGE_W * PT:.2f} {PAGE_H * PT:.2f}] "
            f"/Resources << /Font << /F1 3 0 R >> >> /Contents {content} 0 R >>"
        )
        kids.append(f"{len(objs)} 0 R")
    objs[1] = f"<< /Type /Pages /Kids [{' '.join(kids)}] /Count {len(kids)} >>"
    out = bytearray(b"%PDF-1.4\n")
    offsets = []
    for i, obj in enumerate(objs, 1):
        offsets.append(len(out))
        body = obj if isinstance(obj, bytes) else obj.encode("cp1252")
        out += f"{i} 0 obj\n".encode() + body + b"\nendobj\n"
    xref = len(out)
    out += f"xref\n0 {len(objs) + 1}\n0000000000 65535 f \n".encode()
    for offset in offsets:
        out += f"{offset:010d} 00000 n \n".encode()
    out += f"trailer\n<< /Size {len(objs) + 1} /Root 1 0 R >>\nstartxref\n{xref}\n%%EOF\n".encode()
    path.write_bytes(out)


if __name__ == "__main__":
    write_pdf([right_corner(), left_corner()], Path(__file__).with_name("drill_template.pdf"))

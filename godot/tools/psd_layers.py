"""Just enough of the Photoshop format to lift the tree layer (with its transparency) out of
trees-and-bushes.psd: 8-bit RGB, raw or RLE (PackBits) channels."""
import struct
from pathlib import Path

from PIL import Image


def _unpack_bits(data: bytes, size: int) -> bytes:
    out = bytearray()
    i = 0
    while i < len(data) and len(out) < size:
        n = data[i]
        i += 1
        if n < 128:
            out += data[i:i + n + 1]
            i += n + 1
        elif n > 128:
            out += bytes([data[i]]) * (257 - n)
            i += 1
    return bytes(out[:size])


def layers(path: Path):
    """[(name, left, top, RGBA image)] for every layer of an 8-bit RGB PSD."""
    d = Path(path).read_bytes()
    assert d[:4] == b"8BPS", "not a PSD file"
    channels, height, width, depth, mode = struct.unpack(">HIIHH", d[12:26])
    assert depth == 8 and mode == 3, "only 8-bit RGB files are read"
    p = 26
    p += 4 + struct.unpack(">I", d[p:p + 4])[0]      # colour mode data
    p += 4 + struct.unpack(">I", d[p:p + 4])[0]      # image resources
    p += 4                                           # layer and mask section length
    p += 4                                           # layer info length
    count = abs(struct.unpack(">h", d[p:p + 2])[0])
    p += 2
    records = []
    for _ in range(count):
        top, left, bottom, right, nch = struct.unpack(">iiiiH", d[p:p + 18])
        p += 18
        chans = []
        for _ in range(nch):
            cid, clen = struct.unpack(">hI", d[p:p + 6])
            p += 6
            chans.append((cid, clen))
        p += 12                                      # blend signature, mode, opacity, clipping, flags, filler
        extra = struct.unpack(">I", d[p:p + 4])[0]
        p += 4
        q = p
        q += 4 + struct.unpack(">I", d[q:q + 4])[0]  # layer mask
        q += 4 + struct.unpack(">I", d[q:q + 4])[0]  # blending ranges
        n = d[q]
        name = d[q + 1:q + 1 + n].decode("latin-1")
        p += extra
        records.append((name, top, left, bottom, right, chans))
    out = []
    for name, top, left, bottom, right, chans in records:
        w, h = right - left, bottom - top
        planes = {}
        for cid, clen in chans:
            comp = struct.unpack(">H", d[p:p + 2])[0]
            body = d[p + 2:p + clen]
            if cid >= -1 and w > 0 and h > 0:
                if comp == 0:
                    planes[cid] = body[:w * h]
                elif comp == 1:
                    counts = struct.unpack(f">{h}H", body[:2 * h])
                    rows, at = [], 2 * h
                    for c in counts:
                        rows.append(_unpack_bits(body[at:at + c], w))
                        at += c
                    planes[cid] = b"".join(rows)
            p += clen
        if w > 0 and h > 0 and all(k in planes for k in (0, 1, 2)):
            alpha = planes.get(-1, b"\xff" * (w * h))
            img = Image.merge("RGBA", [Image.frombytes("L", (w, h), planes[k]) for k in (0, 1, 2)] +
                              [Image.frombytes("L", (w, h), alpha)])
            out.append((name, left, top, img))
    return (width, height), out


def tree_layer(path: Path) -> Image.Image:
    """The biggest layer that has transparency (the trees), placed on the file's full canvas."""
    (width, height), found = layers(path)
    see_through = [(img.size[0] * img.size[1], left, top, img) for _, left, top, img in found
                   if img.getextrema()[3][0] == 0 and img.size[1] > height // 2]
    assert see_through, "no layer with transparency in the tree file"
    _, left, top, img = max(see_through, key=lambda x: x[0])
    canvas = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    canvas.paste(img, (left, top))
    return canvas

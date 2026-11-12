#!/usr/bin/env python3
"""Extrae letras sincronizadas (LRC) embebidas en un archivo de audio.

Uso: lyrics.py <ruta-o-url>

Imprime una línea JSON. Formatos admitidos:
  - MP4/M4A: átomo ©lyr (texto LRC).
  - FLAC: comentarios Vorbis SYNCEDLYRICS, LYRICS o UNSYNCEDLYRICS.
  - MP3: marcos SYLT (milisegundos) o USLT con texto LRC.
  - Respaldo: un .lrc junto al archivo.

No depende de mutagen ni de ffprobe: solo de la biblioteca estándar.
"""

import json
import os
import re
import struct
import sys
from urllib.parse import unquote, urlparse


# --------------------------------------------------------------------- utils
def decode_bytes(data, encoding=3):
    """Decodifica texto ID3/MP4. 0 latin-1, 1 utf-16, 2 utf-16be, 3 utf-8."""
    if not data:
        return ""
    try:
        if encoding == 0:
            text = data.decode("latin-1")
        elif encoding == 1:
            text = data.decode("utf-16")
        elif encoding == 2:
            text = data.decode("utf-16-be")
        else:
            text = data.decode("utf-8", "replace")
    except (UnicodeDecodeError, LookupError):
        text = data.decode("utf-8", "replace")
    return text.replace("\x00", "").strip()


def read_until_null(data, start, encoding):
    """Devuelve (texto, bytes consumidos) hasta el terminador de la codificación."""
    if encoding in (1, 2):
        end = start
        while end + 1 < len(data):
            if data[end] == 0 and data[end + 1] == 0:
                return decode_bytes(data[start:end], encoding), end + 2 - start
            end += 2
        return decode_bytes(data[start:], encoding), len(data) - start
    end = data.find(b"\x00", start)
    if end < 0:
        return decode_bytes(data[start:], encoding), len(data) - start
    return decode_bytes(data[start:end], encoding), end + 1 - start


def split_descriptor(data, encoding):
    """Separa el descriptor inicial del texto en USLT/SYLT."""
    _, used = read_until_null(data, 0, encoding)
    return data[used:]


# ----------------------------------------------------------------------- MP4
MP4_CONTAINERS = {
    b"moov", b"udta", b"trak", b"mdia", b"minf", b"stbl",
    b"ilst", b"edts", b"dinf", b"mvex", b"moof", b"traf",
}


def mp4_atoms(data, start, end):
    pos = start
    while pos + 8 <= end:
        size = struct.unpack(">I", data[pos:pos + 4])[0]
        name = data[pos + 4:pos + 8]
        header = 8
        if size == 1:
            if pos + 16 > end:
                break
            size = struct.unpack(">Q", data[pos + 8:pos + 16])[0]
            header = 16
        elif size == 0:
            size = end - pos
        if size < header or pos + size > end:
            break
        yield name, pos + header, pos + size
        pos += size


def mp4_lyrics(data):
    def walk(start, end, depth=0):
        if depth > 12:
            return ""
        for name, body, stop in mp4_atoms(data, start, end):
            if name in (b"\xa9lyr", b"\xa9LYR"):
                for child, cbody, cstop in mp4_atoms(data, body, stop):
                    if child == b"data":
                        # 4 bytes de tipo + 4 de locale antes del texto.
                        return decode_bytes(data[cbody + 8:cstop])
                return decode_bytes(data[body:stop])
            if name in MP4_CONTAINERS or name == b"meta":
                skip = 4 if name == b"meta" else 0
                found = walk(body + skip, stop, depth + 1)
                if found:
                    return found
        return ""

    return walk(0, len(data))


# ---------------------------------------------------------------------- FLAC
def flac_lyrics(data):
    if data[:4] != b"fLaC":
        return ""
    pos = 4
    found = {}
    while pos + 4 <= len(data):
        header = data[pos]
        last = bool(header & 0x80)
        block_type = header & 0x7F
        size = int.from_bytes(data[pos + 1:pos + 4], "big")
        body = data[pos + 4:pos + 4 + size]
        pos += 4 + size
        if block_type == 4 and len(body) >= 8:
            try:
                vendor_len = struct.unpack("<I", body[:4])[0]
                cursor = 4 + vendor_len
                count = struct.unpack("<I", body[cursor:cursor + 4])[0]
                cursor += 4
                for _ in range(count):
                    length = struct.unpack("<I", body[cursor:cursor + 4])[0]
                    cursor += 4
                    item = body[cursor:cursor + length]
                    cursor += length
                    if b"=" not in item:
                        continue
                    key, value = item.split(b"=", 1)
                    key = key.decode("ascii", "ignore").upper()
                    found[key] = decode_bytes(value)
            except (struct.error, ValueError):
                pass
        if last:
            break
    for key in ("SYNCEDLYRICS", "LYRICS", "UNSYNCEDLYRICS"):
        if found.get(key):
            return found[key]
    return ""


# ----------------------------------------------------------------------- MP3
def syncsafe(data):
    if len(data) < 4:
        return 0
    return ((data[0] & 0x7F) << 21) | ((data[1] & 0x7F) << 14) \
        | ((data[2] & 0x7F) << 7) | (data[3] & 0x7F)


def parse_uslt(body):
    if len(body) < 4:
        return ""
    encoding = body[0]
    return decode_bytes(split_descriptor(body[4:], encoding), encoding)


def parse_sylt(body):
    if len(body) < 6:
        return ""
    encoding = body[0]
    timestamp_format = body[4]
    if timestamp_format != 2:
        return ""  # 1 = fotogramas MPEG, no convertible sin el bitrate.
    rest = split_descriptor(body[6:], encoding)
    entries = []
    pos = 0
    while pos < len(rest):
        text, used = read_until_null(rest, pos, encoding)
        pos += used
        if pos + 4 > len(rest):
            break
        stamp = struct.unpack(">I", rest[pos:pos + 4])[0]
        pos += 4
        text = text.strip()
        if text:
            entries.append((stamp / 1000.0, text))
    if not entries:
        return ""
    return "\n".join("[%02d:%05.2f]%s" % (int(t // 60), t % 60, text)
                     for t, text in entries)


def id3_lyrics(data):
    if data[:3] != b"ID3" or len(data) < 10:
        return ""
    major = data[3]
    flags = data[5]
    size = syncsafe(data[6:10])
    body = data[10:10 + size]
    if flags & 0x80:
        body = body.replace(b"\xff\x00", b"\xff")
    pos = 0
    if flags & 0x40 and len(body) >= 4:
        if major == 4:
            pos = syncsafe(body[:4])
        else:
            pos = 4 + struct.unpack(">I", body[:4])[0]
    uslt = ""
    sylt = ""
    while pos + 10 <= len(body):
        frame_id = body[pos:pos + 4]
        if frame_id == b"\x00\x00\x00\x00":
            break
        if major == 4:
            frame_size = syncsafe(body[pos + 4:pos + 8])
        else:
            frame_size = struct.unpack(">I", body[pos + 4:pos + 8])[0]
        frame = body[pos + 10:pos + 10 + frame_size]
        pos += 10 + frame_size
        if frame_size <= 0 or frame_size > len(body):
            break
        if frame_id == b"USLT":
            uslt = parse_uslt(frame)
        elif frame_id == b"SYLT":
            sylt = parse_sylt(frame)
    return sylt or uslt


# ----------------------------------------------------------------------- LRC
STAMP = re.compile(r"\[(\d{1,3}):(\d{1,2}(?:[.:]\d{1,3})?)\]")


def parse_lrc(text):
    lines = []
    seen = set()
    for raw in text.replace("\r\n", "\n").replace("\r", "\n").split("\n"):
        line = raw.strip()
        if not line:
            continue
        stamps = list(STAMP.finditer(line))
        if not stamps:
            continue
        lyric = line[stamps[-1].end():].strip()
        if not lyric:
            continue
        for match in stamps:
            minutes = int(match.group(1))
            seconds = float(match.group(2).replace(":", "."))
            key = (round(minutes * 60 + seconds, 2), lyric)
            if key in seen:
                continue
            seen.add(key)
            lines.append(key)
    lines.sort(key=lambda item: item[0])
    return [{"time": time, "text": lyric} for time, lyric in lines]


# ------------------------------------------------------------------- entrada
def local_path(value):
    if value.startswith("file://"):
        return unquote(urlparse(value).path)
    if value.startswith("/"):
        return value
    return os.path.abspath(unquote(value))


def read_text_file(path):
    with open(path, "rb") as handle:
        data = handle.read()
    for encoding in ("utf-8-sig", "utf-16", "latin-1"):
        try:
            return data.decode(encoding)
        except UnicodeDecodeError:
            continue
    return data.decode("utf-8", "replace")


def extract(value):
    path = local_path(value)
    if not os.path.isfile(path):
        return {"ok": False, "error": "archivo no encontrado"}

    with open(path, "rb") as handle:
        data = handle.read()

    source = ""
    text = ""
    if data[:4] == b"fLaC":
        text = flac_lyrics(data)
        source = "flac"
    elif data[:3] == b"ID3" or path.lower().endswith(".mp3"):
        text = id3_lyrics(data)
        source = "mp3"
    else:
        text = mp4_lyrics(data)
        source = "mp4"

    lines = parse_lrc(text) if text else []

    if not lines:
        sidecar = os.path.splitext(path)[0] + ".lrc"
        if os.path.isfile(sidecar):
            lines = parse_lrc(read_text_file(sidecar))
            source = "lrc"

    if not lines:
        return {
            "ok": True,
            "synced": False,
            "source": source,
            "lines": [],
            "text": text[:2000] if text else "",
        }

    return {"ok": True, "synced": True, "source": source, "lines": lines}


def main():
    if len(sys.argv) < 2:
        print(json.dumps({"ok": False, "error": "falta la ruta"}))
        return 2
    try:
        result = extract(sys.argv[1])
    except (OSError, struct.error, ValueError) as error:
        result = {"ok": False, "error": str(error)}
    print(json.dumps(result, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())

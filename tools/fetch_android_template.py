"""Extract only Android templates from the official release ZIP using HTTP ranges."""
import concurrent.futures
import io
import pathlib
import struct
import urllib.request
import zipfile
import zlib

URL = "https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz"
OUT = pathlib.Path(__file__).resolve().parents[1] / "build/android/toolchain/templates"


def request(start, end):
    for attempt in range(4):
        try:
            req = urllib.request.Request(URL, headers={"Range": f"bytes={start}-{end}", "User-Agent": "PrisonStorm-build"})
            with urllib.request.urlopen(req, timeout=90) as response:
                if response.status != 206:
                    raise RuntimeError("Server did not honor range request")
                data = response.read()
                if len(data) != end - start + 1:
                    raise RuntimeError("Incomplete range")
                return data
        except Exception:
            if attempt == 3:
                raise


def main():
    with urllib.request.urlopen(urllib.request.Request(URL, method="HEAD"), timeout=60) as response:
        length = int(response.headers["Content-Length"])
    tail = request(length - 65557, length - 1)
    offset = tail.rfind(b"PK\x05\x06")
    eocd = tail[offset:]
    fields = struct.unpack_from("<4s4H2IH", eocd)
    directory_size, directory_offset = fields[5:7]
    directory = request(directory_offset, directory_offset + directory_size - 1)
    # zipfile computes the offset of this synthetic central-directory-only ZIP.
    archive = zipfile.ZipFile(io.BytesIO(directory + eocd))
    OUT.mkdir(parents=True, exist_ok=True)
    for info in archive.infolist():
        if info.filename not in ("templates/android_debug.apk", "templates/android_release.apk", "templates/version.txt"):
            continue
        local_offset = info.header_offset + directory_offset
        header = request(local_offset, local_offset + 29)
        name_len, extra_len = struct.unpack_from("<HH", header, 26)
        start = local_offset + 30 + name_len + extra_len
        chunks = [(p, min(p + 1048576, start + info.compress_size) - 1) for p in range(start, start + info.compress_size, 1048576)]
        print(f"Fetching {info.filename}: {info.compress_size / 1048576:.1f} MiB", flush=True)
        with concurrent.futures.ThreadPoolExecutor(max_workers=12) as pool:
            pieces = []
            for index, data in enumerate(pool.map(lambda bounds: request(*bounds), chunks)):
                pieces.append(data)
                if index % 10 == 0:
                    print(f"  {index + 1}/{len(chunks)} chunks", flush=True)
        compressed = b"".join(pieces)
        if info.compress_type == zipfile.ZIP_DEFLATED:
            data = zlib.decompress(compressed, -15)
        elif info.compress_type == zipfile.ZIP_STORED:
            data = compressed
        else:
            raise RuntimeError("Unsupported ZIP compression")
        if len(data) != info.file_size or zlib.crc32(data) != info.CRC:
            raise RuntimeError("Template ZIP checksum mismatch")
        target = OUT / pathlib.PurePosixPath(info.filename).name
        target.write_bytes(data)
        print(f"Verified {target.name}: {len(data)} bytes", flush=True)


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
# Print a CRX3's manifest version; external_version must match it or chromium refuses the install.
import io, json, struct, sys, zipfile

data = open(sys.argv[1], "rb").read()
if data[:4] != b"Cr24":
    sys.exit(f"not a CRX3 file: {sys.argv[1]}")
header_len = struct.unpack("<I", data[8:12])[0]
z = zipfile.ZipFile(io.BytesIO(data[12 + header_len:]))
print(json.loads(z.read("manifest.json"))["version"])

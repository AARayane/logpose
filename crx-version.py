#!/usr/bin/env python3
# Print a CRX3's manifest version. Used at build time so an External Extension
# Descriptor's `external_version` always matches the packaged .crx exactly (chromium
# refuses the install on a mismatch). CRX3 = "Cr24" + u32 version + u32 header_len +
# header + zip; the manifest lives in the trailing zip.
import io, json, struct, sys, zipfile

data = open(sys.argv[1], "rb").read()
if data[:4] != b"Cr24":
    sys.exit(f"not a CRX3 file: {sys.argv[1]}")
header_len = struct.unpack("<I", data[8:12])[0]
z = zipfile.ZipFile(io.BytesIO(data[12 + header_len:]))
print(json.loads(z.read("manifest.json"))["version"])

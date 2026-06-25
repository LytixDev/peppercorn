import sys
import struct

data = open(sys.argv[1], "rb").read()
if len(data) % 4:
    data += b"\x00" * (4 - len(data) % 4)
for i in range(0, len(data), 4):
    print("%08x" % struct.unpack("<I", data[i:i+4])[0])

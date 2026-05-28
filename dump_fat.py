with open("out/lamaos.img", "rb") as f:
    f.seek(0x4200 + (12-2)*512)
    d = f.read(512)
    print(" ".join(f"{b:02x}" for b in d[:32]))
    print(d[:32].decode('latin-1'))

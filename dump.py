with open("out/SHELL.BIN", "rb") as f:
    d = f.read(128)
    print(" ".join(f"{b:02x}" for b in d))

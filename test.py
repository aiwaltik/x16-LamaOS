import subprocess
import time
import socket
import threading

p = subprocess.Popen(
    ["C:/Program Files/qemu/qemu-system-i386.exe", "-fda", "out/lamaos.img", "-boot", "a", "-m", "32", "-display", "none", "-serial", "tcp:127.0.0.1:4444,server,nowait"]
)

time.sleep(2) # wait for qemu to start and bind port

s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.connect(("127.0.0.1", 4444))

output_data = []

def read_output():
    while True:
        try:
            data = s.recv(1024)
            if not data:
                break
            output_data.append(data.decode("utf-8", errors="ignore"))
        except:
            break

t = threading.Thread(target=read_output)
t.daemon = True
t.start()

time.sleep(1)
print("Sending testuser...")
s.sendall(b"testuser\r")

time.sleep(1)
print("Sending ls...")
s.sendall(b"ls\r")

time.sleep(1)
print("Sending calc...")
s.sendall(b"calc\r")

time.sleep(1)
print("Sending 100+50...")
s.sendall(b"100+50\r")

time.sleep(2)
p.kill()
s.close()

full_output = "".join(output_data)

print("\n=== LAMAOS OUTPUT ===")
print(full_output)

if "Result: 150" in full_output and "KERNEL   BIN" in full_output:
    print("\n[SUCCESS] OS Booted, ls worked, calc evaluated correctly!")
    exit(0)
else:
    print("\n[FAILED] Output did not match expectations.")
    exit(1)

import subprocess
import time

p = subprocess.Popen(
    ["C:/Program Files/qemu/qemu-system-i386.exe", "-fda", "out/lamaos.img", "-boot", "a", "-m", "32", "-nographic"],
    stdout=subprocess.PIPE, stderr=subprocess.PIPE, stdin=subprocess.PIPE, text=True, errors="ignore"
)

time.sleep(3)
for c in "testuser\n":
    p.stdin.write(c)
    p.stdin.flush()
    time.sleep(0.1)

time.sleep(3)
for c in "ls\n":
    p.stdin.write(c)
    p.stdin.flush()
    time.sleep(0.1)

time.sleep(2)

p.kill()
stdout, _ = p.communicate()
print("OUTPUT:")
print(stdout)

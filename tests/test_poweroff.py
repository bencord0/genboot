#!/usr/bin/env python
import sys
import os
import signal
import subprocess
from subprocess import PIPE
from contextlib import contextmanager

import time
import threading

OPTIONS = {
    'cpus': 6,
    'memory': 1024,
    'kernel': 'latest/vmlinuz',
    'initrd': 'latest/initramfs',
}
COMMANDS = ["poweroff"]
PROMPT = "root@localhost ~ #"
RUN_CMD = [
    "qemu-system-x86_64",
    "-machine", "accel=kvm:tcg",
    "-smp", "{cpus}".format(**OPTIONS),
    "-m", "{memory}".format(**OPTIONS),
    "-net", "nic,model=virtio",
    "-net", "user",
    "-kernel", "{kernel}".format(**OPTIONS),
    "-initrd", "{initrd}".format(**OPTIONS),
    "-append",
    "console=ttyS0",
    "-nographic",
    ]

@contextmanager
def start_program(args):
    p = subprocess.Popen(args, stdin=PIPE, stdout=PIPE)
    yield p
    if p.poll() is None:
        p.kill()

def failure_timeout():
    print("Starting timer...")
    time.sleep(60)
    print("Test didn't finish in time")
    os.kill(os.getpid(), signal.SIGTERM)

t = threading.Thread(target=failure_timeout)
t.daemon = True
t.start()

command = iter(COMMANDS)
with start_program(RUN_CMD) as q:
    print("Inside context manager")
    for line in q.stdout:
        print(line.decode().strip())
        if PROMPT in line.decode():
            try:
                q.stdin.write((next(command)+'\n').encode())
                q.stdin.flush()
            except StopIteration:
                pass
        q.stdout.flush()

    ret = q.wait()

print("All done! {}".format(ret))
sys.exit(ret)

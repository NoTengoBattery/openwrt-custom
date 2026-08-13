#!/usr/bin/env python3
"""Minimal read-only TFTP server, plain RFC1350 only.

Deliberately ignores all RFC2347/2348/2349/7440 options and never sends an OACK,
because U-Boot 2014.04 mishandles them ("First block is not block 1"). 512-byte
blocks, strict lockstep. Serves as the invoking user, so no chroot/nobody games.

    sudo ./tiny-tftpd.py /tmp/w1700k-tftp [bind-ip]
"""
import os
import socket
import struct
import sys
import threading

ROOT = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else "/tmp/w1700k-tftp")
BIND = sys.argv[2] if len(sys.argv) > 2 else "0.0.0.0"
BLOCK = 512
RETRIES = 6
TIMEOUT = 2.0

RRQ, DATA, ACK, ERROR = 1, 3, 4, 5


def send_error(sock, addr, code, msg):
    sock.sendto(struct.pack("!HH", ERROR, code) + msg.encode() + b"\0", addr)


def serve_file(path, addr):
    """One transfer, from its own ephemeral socket as TFTP requires."""
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.bind((BIND, 0))
    s.settimeout(TIMEOUT)
    sent = 0
    try:
        with open(path, "rb") as f:
            block = 1
            while True:
                chunk = f.read(BLOCK)
                pkt = struct.pack("!HH", DATA, block & 0xFFFF) + chunk
                for attempt in range(RETRIES):
                    s.sendto(pkt, addr)
                    try:
                        rep, raddr = s.recvfrom(1024)
                    except socket.timeout:
                        continue
                    if raddr != addr or len(rep) < 4:
                        continue
                    op, bno = struct.unpack("!HH", rep[:4])
                    if op == ACK and bno == (block & 0xFFFF):
                        break
                    if op == ERROR:
                        print("  client aborted", flush=True)
                        return
                else:
                    print("  timeout at block %d" % block, flush=True)
                    return
                sent += len(chunk)
                block += 1
                if len(chunk) < BLOCK:
                    print("  done, %d bytes" % sent, flush=True)
                    return
    finally:
        s.close()


def main():
    srv = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind((BIND, 69))
    print("tftp root=%s bind=%s:69 (plain RFC1350, no options)" % (ROOT, BIND), flush=True)

    while True:
        data, addr = srv.recvfrom(2048)
        if len(data) < 4 or struct.unpack("!H", data[:2])[0] != RRQ:
            continue
        parts = data[2:].split(b"\0")
        name = parts[0].decode("latin-1")
        path = os.path.abspath(os.path.join(ROOT, name))
        if not path.startswith(ROOT) or not os.path.isfile(path):
            print("%s -> %s NOT FOUND" % (addr[0], name), flush=True)
            send_error(srv, addr, 1, "File not found")
            continue
        print("%s -> %s (%d bytes)" % (addr[0], name, os.path.getsize(path)), flush=True)
        # One thread per transfer: serving inline meant a stalled transfer kept
        # retransmitting while the listener blocked, so the client's *next*
        # request was answered with a stale block ("First block is not block 1").
        threading.Thread(target=serve_file, args=(path, addr), daemon=True).start()


if __name__ == "__main__":
    main()

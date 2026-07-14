#!/usr/bin/env python3
"""Minimal Source-RCON client: send one command to a Factorio server.

Usage: rcon_client.py HOST PORT PASSWORD COMMAND
Prints the server's response body to stdout.
"""
import socket
import struct
import sys

SERVERDATA_AUTH = 3
SERVERDATA_AUTH_RESPONSE = 2
SERVERDATA_EXECCOMMAND = 2
SERVERDATA_RESPONSE_VALUE = 0


def send_packet(sock, req_id, ptype, body):
    payload = struct.pack("<ii", req_id, ptype) + body.encode("utf-8") + b"\x00\x00"
    sock.sendall(struct.pack("<i", len(payload)) + payload)


def recv_packet(sock):
    def recv_exact(n):
        buf = b""
        while len(buf) < n:
            chunk = sock.recv(n - len(buf))
            if not chunk:
                raise ConnectionError("connection closed by server")
            buf += chunk
        return buf

    (size,) = struct.unpack("<i", recv_exact(4))
    data = recv_exact(size)
    req_id, ptype = struct.unpack("<ii", data[:8])
    body = data[8:-2].decode("utf-8", errors="replace")
    return req_id, ptype, body


def main():
    host, port, password, command = sys.argv[1], int(sys.argv[2]), sys.argv[3], sys.argv[4]
    with socket.create_connection((host, port), timeout=10) as sock:
        sock.settimeout(10)
        send_packet(sock, 1, SERVERDATA_AUTH, password)
        # Some servers send an empty RESPONSE_VALUE before AUTH_RESPONSE.
        while True:
            req_id, ptype, _ = recv_packet(sock)
            if ptype == SERVERDATA_AUTH_RESPONSE:
                break
        if req_id == -1:
            sys.exit("RCON authentication failed")

        send_packet(sock, 2, SERVERDATA_EXECCOMMAND, command)
        _, _, body = recv_packet(sock)
        print(body, end="")


if __name__ == "__main__":
    main()

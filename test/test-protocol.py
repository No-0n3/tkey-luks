#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2025 TKey-LUKS Project
# SPDX-License-Identifier: BSD-2-Clause

"""
Simple protocol tester for TKey-LUKS device app.
Tests protocol commands without using tkeyclient library.
"""

import sys
import serial
import time
import struct

# Protocol command codes
CMD_SET_CHALLENGE = 0x03
RSP_SET_CHALLENGE = 0x04
CMD_LOAD_CHALLENGE = 0x05
RSP_LOAD_CHALLENGE = 0x06
CMD_DERIVE_KEY = 0x07
RSP_DERIVE_KEY = 0x08
CMD_GET_NAMEVERSION = 0x09
RSP_GET_NAMEVERSION = 0x0a

# Framing protocol
DST_SW = 0x03  # Software/application endpoint (DST_SW = 3 in tkey-libs v0.1.2)
LEN_1 = 0x00   # enum cmdlen values are 0, 1, 2, 3
LEN_4 = 0x01
LEN_32 = 0x02
LEN_128 = 0x03

# Status codes
STATUS_OK = 0
STATUS_BAD = 1

def genhdr(id, endpoint, status, length):
    """Generate TKey frame header byte"""
    return ((id & 0x3) << 5) | ((endpoint & 0x3) << 3) | ((status & 0x1) << 2) | (length & 0x3)

def parsehdr(header):
    """Parse TKey frame header byte"""
    id = (header >> 5) & 0x3
    endpoint = (header >> 3) & 0x3
    status = (header >> 2) & 0x1
    length = header & 0x3
    return id, endpoint, status, length

def length_to_code(nbytes):
    """Convert byte count to length code"""
    if nbytes == 1:
        return LEN_1
    elif nbytes <= 4:
        return LEN_4
    elif nbytes <= 32:
        return LEN_32
    elif nbytes <= 128:
        return LEN_128
    else:
        raise ValueError(f"Invalid frame length: {nbytes}")

def code_to_length(code):
    """Convert length code to byte count"""
    if code == 0x00:  # LEN_1
        return 1
    elif code == 0x01:  # LEN_4
        return 4
    elif code == 0x02:  # LEN_32
        return 32
    elif code == 0x03:  # LEN_128
        return 128
    else:
        raise ValueError(f"Invalid length code: {code:#x}")

def open_tkey(port="/dev/ttyACM0", baudrate=62500):
    """Open serial connection to TKey"""
    try:
        ser = serial.Serial(port, baudrate, timeout=2)
        time.sleep(0.1)  # Give device time to settle
        return ser
    except Exception as e:
        print(f"Failed to open {port}: {e}", file=sys.stderr)
        return None

def send_command(ser, frame_id, cmd_code, data=b''):
    """Send a properly framed command"""
    # Calculate total length (cmd_code + data)
    total_len = 1 + len(data)
    
    # Determine length code
    if total_len <= 1:
        len_code = LEN_1
        frame_size = 1
    elif total_len <= 4:
        len_code = LEN_4
        frame_size = 4
    elif total_len <= 32:
        len_code = LEN_32
        frame_size = 32
    elif total_len <= 128:
        len_code = LEN_128
        frame_size = 128
    else:
        raise ValueError(f"Data too large: {len(data)} bytes")
    
    # Generate frame header
    hdr = genhdr(frame_id, DST_SW, 0, len_code)
    
    # Build frame: [header][cmd_code][data][padding]
    frame = bytes([hdr, cmd_code]) + data
    # Pad to frame size
    if len(frame) < frame_size + 1:  # +1 for header
        frame += b'\x00' * (frame_size + 1 - len(frame))
    
    print(f"TX: id={frame_id} cmd=0x{cmd_code:02x} len={len_code:#x} size={len(frame)} bytes")
    if data:
        print(f"    data[0:16]={data[:16].hex()}")
    ser.write(frame)
    ser.flush()

def read_response(ser, frame_id, expected_rsp, timeout=2):
    """Read a properly framed response"""
    ser.timeout = timeout
    
    # Read frame header
    hdr_byte = ser.read(1)
    if len(hdr_byte) == 0:
        print("RX: timeout waiting for response", file=sys.stderr)
        return None
    
    hdr = hdr_byte[0]
    rx_id, endpoint, status, length = parsehdr(hdr)
    frame_len = code_to_length(length)
    
    print(f"RX: id={rx_id} ep={endpoint} status={status} len={length:#x} ({frame_len} bytes)")
    
    if rx_id != frame_id:
        print(f"  WARNING: frame ID mismatch (expected {frame_id}, got {rx_id})", file=sys.stderr)
    
    if status != 0:
        print(f"  ERROR: status NOK", file=sys.stderr)
        return None
    
    # Read frame payload
    frame_data = ser.read(frame_len)
    if len(frame_data) < frame_len:
        print(f"  ERROR: short frame, expected {frame_len}, got {len(frame_data)}", file=sys.stderr)
        return None
    
    # First byte should be response code
    rsp_code = frame_data[0]
    payload = frame_data[1:]
    
    print(f"    rsp=0x{rsp_code:02x}")
    
    if rsp_code != expected_rsp:
        print(f"  ERROR: expected 0x{expected_rsp:02x}, got 0x{rsp_code:02x}", file=sys.stderr)
        return None
    
    return payload

def test_get_nameversion(ser):
    """Test CMD_GET_NAMEVERSION"""
    print("\n=== Testing GET_NAMEVERSION ===")
    frame_id = 1
    send_command(ser, frame_id, CMD_GET_NAMEVERSION)
    rsp = read_response(ser, frame_id, RSP_GET_NAMEVERSION)
    if rsp and len(rsp) >= 11:
        name0 = rsp[0:4].decode('ascii', errors='replace')
        name1 = rsp[4:8].decode('ascii', errors='replace')
        version = struct.unpack('<I', rsp[8:12])[0]
        print(f"  Name: {name0}{name1}")
        print(f"  Version: {version}")
        return True
    return False

def test_set_challenge(ser, size):
    """Test CMD_SET_CHALLENGE"""
    print(f"\n=== Testing SET_CHALLENGE (size={size}) ===")
    frame_id = 2
    # Send size as 32 bytes (4 byte size + padding)
    data = struct.pack('<I', size) + b'\x00' * 27
    send_command(ser, frame_id, CMD_SET_CHALLENGE, data)
    rsp = read_response(ser, frame_id, RSP_SET_CHALLENGE)
    if rsp and len(rsp) >= 1:
        status = rsp[0]
        print(f"  Status: {status} ({'OK' if status == STATUS_OK else 'BAD'})")
        return status == STATUS_OK
    return False

def test_load_challenge(ser, challenge):
    """Test CMD_LOAD_CHALLENGE"""
    print(f"\n=== Testing LOAD_CHALLENGE (size={len(challenge)}) ===")
    # Send challenge in 127-byte chunks
    offset = 0
    chunk_num = 0
    while offset < len(challenge):
        frame_id = 3 + (chunk_num % 4)  # Rotate frame IDs
        chunk = challenge[offset:offset+127]
        # Pad to 127 bytes
        data = chunk + b'\x00' * (127 - len(chunk))
        print(f"  Sending chunk {offset}..{offset+len(chunk)}")
        send_command(ser, frame_id, CMD_LOAD_CHALLENGE, data)
        rsp = read_response(ser, frame_id, RSP_LOAD_CHALLENGE)
        if not rsp or len(rsp) < 1:
            return False
        status = rsp[0]
        if status != STATUS_OK:
            print(f"  Status: {status} (BAD)", file=sys.stderr)
            return False
        offset += len(chunk)
        chunk_num += 1
    print("  All chunks sent successfully")
    return True

def test_derive_key(ser):
    """Test CMD_DERIVE_KEY"""
    print(f"\n=== Testing DERIVE_KEY ===")
    print("  NOTE: You may need to touch the TKey now!")
    frame_id = 0
    send_command(ser, frame_id, CMD_DERIVE_KEY)
    rsp = read_response(ser, frame_id, RSP_DERIVE_KEY, timeout=35)  # Long timeout for touch
    if rsp and len(rsp) >= 64:
        key = rsp[0:64]
        print(f"  Derived key: {key.hex()}")
        return key
    return None

def main():
    if len(sys.argv) < 2:
        print("Usage: test-protocol.py <port> [challenge]")
        print("Example: test-protocol.py /dev/ttyACM0 'test-challenge'")
        sys.exit(1)
    
    port = sys.argv[1]
    challenge = sys.argv[2].encode() if len(sys.argv) > 2 else b"default-challenge"
    
    print(f"Opening TKey on {port}...")
    print(f"Challenge: {challenge.decode()!r} ({len(challenge)} bytes)")
    
    ser = open_tkey(port)
    if not ser:
        sys.exit(1)
    
    try:
        # Test name/version
        if not test_get_nameversion(ser):
            print("\nFAILED: GET_NAMEVERSION", file=sys.stderr)
            sys.exit(1)
        
        # Test set challenge size
        if not test_set_challenge(ser, len(challenge)):
            print("\nFAILED: SET_CHALLENGE", file=sys.stderr)
            sys.exit(1)
        
        # Test load challenge data
        if not test_load_challenge(ser, challenge):
            print("\nFAILED: LOAD_CHALLENGE", file=sys.stderr)
            sys.exit(1)
        
        # Test derive key
        key = test_derive_key(ser)
        if not key:
            print("\nFAILED: DERIVE_KEY", file=sys.stderr)
            sys.exit(1)
        
        print("\n=== ALL TESTS PASSED ===")
        print(f"Final key: {key.hex()}")
        
    finally:
        ser.close()

if __name__ == "__main__":
    main()

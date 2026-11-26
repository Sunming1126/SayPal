"""OpenSpeech v3 framing adapted from example/backend/agent_api/app.py.

PCM is little-endian signed 16-bit, mono, 16000 Hz. Frame lengths are big-endian.
"""
import gzip
import json
import struct


def frame(payload: bytes, *, audio: bool = False, last: bool = False) -> bytes:
    return bytes([0x11, 0x22 if last else (0x20 if audio else 0x10),
                  0 if audio else 0x10, 0]) + struct.pack('>I', len(payload)) + payload


def decode(data: bytes) -> tuple[dict, bool]:
    if len(data) < 8:
        raise ValueError('invalid_asr_frame')
    offset = (data[0] & 15) * 4
    kind, flags = data[1] >> 4, data[1] & 15
    if kind == 15:
        # Error frame: header + ErrorCode(uint32) + PayloadSize(uint32) + Payload.
        # Keep only the numeric code for diagnosability; never log payload bodies.
        if offset + 8 > len(data):
            raise ValueError('asr_rejected')
        code = struct.unpack('>I', data[offset:offset + 4])[0]
        raise ValueError(f'asr_rejected_{code}')
    if flags in (1, 3):
        offset += 4
    if offset + 4 > len(data):
        raise ValueError('invalid_asr_frame')
    size = struct.unpack('>I', data[offset:offset + 4])[0]
    payload = data[offset + 4:]
    if size != len(payload) or size > 1_000_000:
        raise ValueError('invalid_asr_frame')
    if data[2] & 15 == 1:
        payload = gzip.decompress(payload)
    return json.loads(payload), flags in (2, 3)

import importlib.machinery
import importlib.util
from pathlib import Path
import unittest
from unittest.mock import patch
import tempfile
import json
import base64
import hashlib
import struct
import time
import os

loader = importlib.machinery.SourceFileLoader('researchmon', str(Path(__file__).parents[1] / 'bin/researchmon'))
spec = importlib.util.spec_from_loader(loader.name, loader)
monitor = importlib.util.module_from_spec(spec)
loader.exec_module(monitor)


class SummaryTests(unittest.TestCase):
    def test_states(self):
        cases = [
            ([], 'Research: none'),
            ([{'type': 'active', 'activeFlags': []}], 'Research: 1 running'),
            ([{'type': 'active', 'activeFlags': ['waitingOnApproval']}], 'Research: 1 waiting'),
            ([{'type': 'active', 'activeFlags': ['waitingOnUserInput']}], 'Research: 1 waiting'),
            ([{'type': 'idle'}], 'Research: 1 idle'),
            ([{'type': 'notLoaded'}], 'Research: 1 unloaded'),
            ([{'type': 'systemError'}], 'Research: 1 error'),
            ([{'type': 'futureState'}], 'Research: 1 unknown'),
        ]
        for statuses, expected in cases:
            with self.subTest(statuses=statuses):
                self.assertEqual(monitor.summary(statuses), expected)

    def test_waiting_is_not_counted_as_running(self):
        self.assertEqual(monitor.summary([
            {'type': 'active', 'activeFlags': []},
            {'type': 'active', 'activeFlags': ['waitingOnApproval']},
            {'type': 'idle'},
        ]), 'Research: 1 running | 1 waiting | 1 idle')


class FakeSocket:
    def __init__(self):
        self.buffer = b''
        self.sent = []
        self.closed = False

    def connect(self, path):
        pass

    def settimeout(self, timeout):
        pass

    def close(self):
        self.closed = True

    def recv(self, length):
        data, self.buffer = self.buffer[:min(length, 3)], self.buffer[min(length, 3):]
        return data

    def sendall(self, data):
        if data.startswith(b'GET '):
            key = data.decode().split('Sec-WebSocket-Key: ')[1].split('\r\n')[0]
            accept = base64.b64encode(hashlib.sha1((key + '258EAFA5-E914-47DA-95CA-C5AB0DC85B11').encode()).digest())
            self.buffer += b'HTTP/1.1 101 Switching Protocols\r\nSec-WebSocket-Accept: ' + accept + b'\r\n\r\n'
            return
        size = data[1] & 127
        offset = 2
        if size == 126:
            size = struct.unpack('!H', data[2:4])[0]
            offset = 4
        mask = data[offset:offset + 4]
        payload = bytes(value ^ mask[i % 4] for i, value in enumerate(data[offset + 4:]))
        self.sent.append((data[0] & 15, payload))

    def frame(self, payload, opcode=1, final=True):
        header = bytes([(128 if final else 0) | opcode])
        size = len(payload)
        header += bytes([size]) if size < 126 else bytes([126]) + struct.pack('!H', size)
        self.buffer += header + payload


class ConnectionTests(unittest.TestCase):
    def test_fragmented_response_with_ping_and_notification(self):
        sock = FakeSocket()
        with patch.object(monitor.socket, 'socket', return_value=sock):
            with monitor.Connection() as connection:
                sock.frame(b'{"method":"notification"}')
                response = json.dumps({'id': 1, 'result': {'detail': 'x' * 200}}).encode()
                sock.frame(response[:160], final=False)
                sock.frame(b'ping', opcode=9)
                sock.frame(response[160:], opcode=0)
                result = connection.request('thread/read', {}, time.monotonic() + 1)
                self.assertEqual(result['detail'], 'x' * 200)
                self.assertIn((10, b'ping'), sock.sent)
        self.assertTrue(sock.closed)

    def test_closed_socket(self):
        sock = FakeSocket()
        with patch.object(monitor.socket, 'socket', return_value=sock):
            with monitor.Connection() as connection:
                with self.assertRaises(ConnectionError):
                    connection.request('thread/read', {}, time.monotonic() + 1)
        self.assertTrue(sock.closed)


class CacheTests(unittest.TestCase):
    def test_cache_expiry(self):
        with tempfile.TemporaryDirectory() as directory, patch.object(monitor, 'STORE', Path(directory)):
            self.assertEqual(monitor.cached(), 'Research: disconnected')
            monitor.publish('Research: 2 running')
            self.assertEqual(monitor.cached(), 'Research: 2 running')
            os.utime(Path(directory) / 'status', (0, 0))
            self.assertEqual(monitor.cached(), 'Research: disconnected')

    def test_connection_failure_does_not_report_zero_running(self):
        with patch.object(monitor, 'tracked', return_value=['thread']), patch.object(monitor, 'Connection', side_effect=OSError):
            self.assertEqual(monitor.sample(), 'Research: disconnected')


if __name__ == '__main__':
    unittest.main()

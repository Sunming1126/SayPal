import asyncio
import threading
import unittest

from fastapi.testclient import TestClient

from saypal.app import create_app


class StubProvider:
    def __init__(self):
        self.release_metadata = threading.Event()
        self.direct_requests = 0

    def missing(self):
        return []

    async def stream_reply(self, history, context_prompt=''):
        yield 'Nice to meet you!'

    async def speak(self, text):
        return 'YXVkaW8='

    async def reply_metadata(self, **kwargs):
        while not self.release_metadata.is_set():
            await asyncio.sleep(0.01)
        return {'translations': ['很高兴认识你！'], 'correction': ''}

    async def translate_text(self, text):
        self.direct_requests += 1
        return '很高兴认识你！'


class TranslationTest(unittest.TestCase):
    def test_voice_finishes_before_slow_metadata_then_reuses_translation(self):
        provider = StubProvider()
        # Give a broken implementation a bounded wait before failing.
        safety_timer = threading.Timer(3, provider.release_metadata.set)
        safety_timer.start()
        try:
            with TestClient(create_app(provider)) as client:
                with client.websocket_connect('/chat/voice') as socket:
                    self.assertEqual(socket.receive_json()['type'], 'ready')
                    socket.send_json({'type': 'text', 'text': 'Hello'})
                    events = [socket.receive_json() for _ in range(4)]
                    self.assertEqual([e['type'] for e in events],
                                     ['transcript', 'reply_segment', 'audio', 'done'])
                    self.assertFalse(provider.release_metadata.is_set())
                    provider.release_metadata.set()
                    metadata = socket.receive_json()
                    self.assertEqual(metadata['type'], 'reply_meta')
                    segment = events[1]
                    socket.send_json({'type': 'translate', 'id': segment['id'], 'text': segment['text']})
                    self.assertEqual(socket.receive_json(), {
                        'type': 'reply_translation', 'id': segment['id'], 'translation': '很高兴认识你！'})
                    self.assertEqual(provider.direct_requests, 0)
        finally:
            provider.release_metadata.set()
            safety_timer.cancel()


if __name__ == '__main__':
    unittest.main()

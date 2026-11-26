import asyncio
from contextlib import asynccontextmanager
import json
import unittest
from unittest.mock import patch

from saypal.protocol import frame
from saypal.providers import Providers


class StreamingRecognitionTest(unittest.IsolatedAsyncioTestCase):
    async def test_definite_utterance_before_release_does_not_end_recording(self):
        audio = asyncio.Queue()
        partials = asyncio.Queue()
        sent = asyncio.Queue()
        responses = asyncio.Queue()

        class Socket:
            send = sent.put
            recv = responses.get

        @asynccontextmanager
        async def open_socket(*args, **kwargs):
            yield Socket()

        def result(text, *, final=False):
            payload = json.dumps({
                'result': {'text': text, 'utterances': [{'definite': True}]},
            }).encode()
            return frame(payload, last=final)

        with patch.object(Providers, 'asr_headers', return_value={}), \
                patch('saypal.providers.connect', open_socket):
            recognition = asyncio.create_task(Providers().recognize(audio, partials.put))
            try:
                await asyncio.wait_for(sent.get(), 1)  # Provider configuration.
                await audio.put(b'\x01\x02')
                self.assertEqual(await asyncio.wait_for(sent.get(), 1),
                                 frame(b'\x01\x02', audio=True))
                await responses.put(result('Hello.'))
                self.assertEqual(await asyncio.wait_for(partials.get(), 1), 'Hello.')
                self.assertFalse(recognition.done())

                await audio.put(b'\x03\x04')
                await audio.put(None)
                self.assertEqual(await asyncio.wait_for(sent.get(), 1),
                                 frame(b'\x03\x04', audio=True))
                self.assertEqual(await asyncio.wait_for(sent.get(), 1),
                                 frame(b'', audio=True, last=True))
                await responses.put(result('Hello. I like apples.', final=True))
                self.assertEqual(await asyncio.wait_for(recognition, 1),
                                 'Hello. I like apples.')
            finally:
                recognition.cancel()
                await asyncio.gather(recognition, return_exceptions=True)

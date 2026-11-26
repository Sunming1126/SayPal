import asyncio
import os
import unittest
from unittest.mock import patch

from saypal.rtc_gateway import RtcGateway


class RtcGatewayTest(unittest.IsolatedAsyncioTestCase):
    async def test_stop_during_start_stops_the_same_cloud_task(self):
        gateway = RtcGateway()
        starting = asyncio.Event()
        release_start = asyncio.Event()
        calls = []

        async def call(action, body):
            calls.append((action, body['TaskId']))
            if action == 'StartVoiceChat':
                starting.set()
                await release_start.wait()

        env = dict.fromkeys((
            'VOLC_RTC_APP_ID', 'VOLC_RTC_APP_KEY', 'VOLC_ACCESS_KEY',
            'VOLC_SECRET_KEY', 'OPENSPEECH_APP_ID', 'OPENSPEECH_ACCESS_TOKEN',
            'ARK_MODEL_ID',
        ), 'test')
        with patch.dict(os.environ, env), patch.object(gateway, '_call', call):
            session_id = gateway.bootstrap(None)['sessionId']
            self.assertEqual(calls, [])
            start = asyncio.create_task(gateway.start(session_id))
            await asyncio.wait_for(starting.wait(), timeout=1)
            stop = asyncio.create_task(gateway.stop(session_id))
            await asyncio.sleep(0)
            self.assertFalse(stop.done())
            release_start.set()
            started, _ = await asyncio.gather(start, stop)
            self.assertEqual(calls, [
                ('StartVoiceChat', started['taskId']),
                ('StopVoiceChat', started['taskId']),
            ])
            await gateway.stop(session_id)
            with self.assertRaises(KeyError):
                await gateway.start(session_id)

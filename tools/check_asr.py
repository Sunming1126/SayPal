"""Check ASR with a validated synthetic PCM file; never accesses a microphone."""
import argparse
import array
import asyncio
import json
from pathlib import Path

from websockets.asyncio.client import connect


ROOT = Path(__file__).resolve().parents[1]


async def main(path):
    pcm = path.read_bytes()
    samples = array.array('h', pcm)
    if len(samples) < 1600 or max(map(abs, samples), default=0) < 100:
        raise SystemExit('Test input is empty, too short or silent; no network request sent.')
    config = json.loads((ROOT / '.local/saypal-online.json').read_text())
    url = config['SAYPAL_API_BASE_URL'].replace('https://', 'wss://') + '/chat/voice'
    headers = {'Authorization': 'Bearer ' + config['SAYPAL_CHAT_TOKEN']}
    result = {'input': 'validated synthetic PCM, no microphone',
              'input_bytes': len(pcm), 'transcript_received': False, 'events': {}, 'errors': []}
    try:
        async with connect(url, additional_headers=headers, proxy=None,
                           open_timeout=15, max_size=5_000_000) as ws:
            assert json.loads(await ws.recv())['type'] == 'ready'

            async def receive():
                async with asyncio.timeout(80):
                    while True:
                        event = json.loads(await ws.recv())
                        kind = event['type']
                        result['events'][kind] = result['events'].get(kind, 0) + 1
                        if kind == 'transcript':
                            result['transcript_received'] = bool(event.get('text'))
                            result['transcript'] = event.get('text')
                        if kind == 'error':
                            result['errors'].append(event.get('message'))
                        if kind == 'done':
                            return

            receiver = asyncio.create_task(receive())
            try:
                await ws.send(json.dumps({'type': 'start'}))
                for offset in range(0, len(pcm), 3200):
                    if receiver.done():
                        break
                    await ws.send(pcm[offset:offset + 3200])
                    await asyncio.sleep(.1)
                if not receiver.done():
                    await ws.send(json.dumps({'type': 'end'}))
                await receiver
            finally:
                receiver.cancel()
                await asyncio.gather(receiver, return_exceptions=True)
    except Exception as error:
        result['error_type'] = type(error).__name__
    (ROOT / '.local/asr-check.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps(result, ensure_ascii=False))
    return result['transcript_received']


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('pcm', type=Path, help='16 kHz mono signed little-endian PCM')
    args = parser.parse_args()
    raise SystemExit(0 if asyncio.run(main(args.pcm)) else 1)

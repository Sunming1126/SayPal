"""Bounded live checks using synthetic speech; does not launch the app."""
import argparse
import asyncio
import base64
from collections import Counter
import json
from pathlib import Path
import shutil
import subprocess
import time

import httpx
from functools import partial
import inspect
from websockets.asyncio.client import connect as websocket_connect
from websockets.exceptions import InvalidStatus


ROOT = Path(__file__).resolve().parents[1]
RESULTS = []
# websockets 15 auto-enables environment proxies; native app sockets are direct.
connect = partial(websocket_connect, proxy=None) if 'proxy' in inspect.signature(websocket_connect).parameters else websocket_connect


def record(name, ok, **evidence):
    RESULTS.append({'check': name, 'passed': bool(ok), **evidence})
    print(json.dumps(RESULTS[-1], ensure_ascii=False), flush=True)


async def turn(ws, name, command, progress=None):
    await ws.send(json.dumps(command))
    counts, audio, texts, errors = Counter(), [], [], []
    started = time.monotonic()
    async with asyncio.timeout(100):
        while True:
            event = json.loads(await ws.recv())
            kind = event.get('type', 'unknown')
            counts[kind] += 1
            if kind == 'audio':
                audio.append(base64.b64decode(event['data'], validate=True))
            if kind == 'reply_segment':
                texts.append(event.get('text', ''))
            if kind == 'error':
                # The public API supplies fixed, credential-free user messages.
                errors.append(event.get('message', 'error'))
            if kind == 'done':
                break
    ok = bool(texts and audio and not errors)
    if progress:
        ok = ok and counts[progress] > 0
    record(name, ok, events=dict(counts), audio_bytes=sum(map(len, audio)),
           seconds=round(time.monotonic() - started, 2), errors=errors)
    return b''.join(audio)


async def main(args):
    config = json.loads(args.config.read_text())
    base = config['SAYPAL_API_BASE_URL'].rstrip('/')
    headers = {'Authorization': 'Bearer ' + config['SAYPAL_CHAT_TOKEN']}
    wsurl = base.replace('https://', 'wss://', 1) + '/chat/voice'
    async with httpx.AsyncClient(timeout=50) as client:
        health = await client.get(base + '/health')
        record('health', health.status_code == 200 and
               health.json().get('configured') is True, status=health.status_code,
               health=health.json())
        for label, auth in [('missing_token', {}),
                            ('invalid_token', {'Authorization': 'Bearer invalid-smoke-token'})]:
            response = await client.post(base + '/translate', json={'text': 'Hello'}, headers=auth)
            record(label, response.status_code == 403, status=response.status_code)
        try:
            async with connect(wsurl, open_timeout=15):
                record('websocket_requires_token', False)
        except InvalidStatus as error:
            record('websocket_requires_token', error.response.status_code == 403,
                   status=error.response.status_code)
        translated = await client.post(base + '/translate', json={'text': 'Hello, how are you?'}, headers=headers)
        record('translation', translated.status_code == 200 and
               bool(translated.json().get('translation')), status=translated.status_code)
        draft = await client.post(base + '/scene-draft', json={'idea': '在售票处购买一张虚构的门票'}, headers=headers)
        draft_body = draft.json()
        valid_draft = draft.status_code == 200 and len(draft_body.get('objectives', [])) == 3
        record('custom_scene_generation', valid_draft, status=draft.status_code)
        async with connect(wsurl, additional_headers=headers, open_timeout=15, max_size=5_000_000) as ws:
            ready = json.loads(await asyncio.wait_for(ws.recv(), 15))
            record('websocket_authenticated', ready.get('type') == 'ready')
            audio = await turn(ws, 'free_chat_llm_tts', {'type': 'text', 'text': 'Hello! I like apples.'})
            if audio and shutil.which('ffmpeg'):
                decoded = subprocess.run(
                    ['ffmpeg', '-v', 'error', '-i', 'pipe:0', '-t', '8', '-f', 's16le',
                     '-ar', '16000', '-ac', '1', 'pipe:1'], input=audio,
                    capture_output=True, timeout=15,
                )
                pcm = decoded.stdout
                record('generated_audio_decodes', decoded.returncode == 0 and len(pcm) > 3200,
                       pcm_bytes=len(pcm))
                if decoded.returncode == 0 and pcm:
                    await ws.send(json.dumps({'type': 'start'}))
                    for offset in range(0, len(pcm), 3200):
                        await ws.send(pcm[offset:offset + 3200])
                        await asyncio.sleep(0.1)
                    await turn(ws, 'synthetic_speech_asr_llm_tts', {'type': 'end'})
            roleplay = json.loads((ROOT / 'assets/content/roleplay_catalog.json').read_text())['scenarios'][0]
            course = json.loads((ROOT / 'assets/content/tutor_courses.json').read_text())['courses'][0]
            cases = [('roleplay', {'catalogId': roleplay['id']}, 'practice_progress'),
                     ('tutorTranslation', {'catalogId': course['id']}, 'tutor_progress'),
                     ('tutorEnglishQa', {'catalogId': course['id']}, 'tutor_progress')]
            if valid_draft:
                cases.append(('customRoleplay', draft_body, 'practice_progress'))
            for kind, context, progress in cases:
                await ws.send(json.dumps({'type': 'configure', 'context': {**context, 'kind': kind}}))
                configured = json.loads(await asyncio.wait_for(ws.recv(), 15))
                record(kind + '_configuration', configured.get('type') == 'configured',
                       event=configured.get('type'))
                if configured.get('type') == 'configured':
                    await turn(ws, kind + '_reply', {'type': 'text', 'text': 'Hello, I am ready.'}, progress)
        if args.rtc:
            bootstrap = await client.post(base + '/rtc/session/bootstrap', json={}, headers=headers)
            data = bootstrap.json()
            record('rtc_bootstrap', bootstrap.status_code == 200 and bool(data.get('token')),
                   status=bootstrap.status_code)
            session_id = data.get('sessionId')
            if session_id:
                try:
                    start = await client.post(base + f'/rtc/session/{session_id}/start', headers=headers)
                    record('rtc_start', start.status_code == 200 and bool(start.json().get('taskId')),
                           status=start.status_code)
                finally:
                    stop = await client.post(base + f'/rtc/session/{session_id}/stop', headers=headers)
                    record('rtc_stop', stop.status_code == 200 and stop.json().get('stopped') is True,
                           status=stop.status_code)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--config', type=Path, default=ROOT / '.local/saypal-online.json')
    parser.add_argument('--rtc', action='store_true', help='Also briefly start and stop a managed RTC task.')
    args = parser.parse_args()
    try:
        asyncio.run(main(args))
    except Exception as error:
        # Exception representations may contain headers or credential-bearing URLs.
        record('check_completed', False, error_type=type(error).__name__)
    finally:
        target = ROOT / '.local/online-check.json'
        target.write_text(json.dumps(RESULTS, ensure_ascii=False, indent=2) + '\n')
    raise SystemExit(0 if RESULTS and all(item['passed'] for item in RESULTS) else 1)

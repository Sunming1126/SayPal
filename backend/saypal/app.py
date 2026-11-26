"""Loopback-only development API. Not an Internet-ready deployment."""
import asyncio
import contextlib
import hmac
import json
import logging
import os
import re
import time
from pathlib import Path
from uuid import uuid4

from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException, Request, WebSocket, WebSocketDisconnect

from .providers import Providers
from .practice_catalog import progress_after_turn, prompt_for, validate_context
from .rtc_gateway import RtcGateway

logger = logging.getLogger('saypal.voice')

load_dotenv(Path(__file__).resolve().parents[1] / '.env')


async def _translate_text(upstream, text):
    if hasattr(upstream, 'translate_text'):
        return await upstream.translate_text(text)
    metadata = await upstream.reply_metadata(
        learner_text='', reply=text, segments=[text],
    )
    translations = metadata.get('translations') or []
    if not translations or not str(translations[0]).strip():
        raise ValueError('empty_translation')
    return str(translations[0]).strip()[:500]


def create_app(provider=None):
    api = FastAPI(docs_url=None, redoc_url=None)
    upstream = provider or Providers()
    rtc = RtcGateway()
    # Bound local concurrency to avoid accidental unbounded provider billing.
    slots = asyncio.Semaphore(2)

    @api.get('/health')
    async def health():
        return {
            'status': 'ok',
            'configured': not upstream.missing(),
            'rtcConfigured': not rtc.missing(),
        }

    def require_native_client(request: Request):
        if request.headers.get('origin') or (
            os.getenv('SAYPAL_CHAT_TOKEN')
            and not hmac.compare_digest(
                request.headers.get('authorization', ''),
                'Bearer ' + os.environ['SAYPAL_CHAT_TOKEN'],
            )
        ):
            raise HTTPException(status_code=403, detail='forbidden')

    @api.post('/rtc/session/bootstrap')
    async def rtc_bootstrap(request: Request):
        require_native_client(request)
        if rtc.missing():
            raise HTTPException(status_code=503, detail='rtc_not_configured')
        body = await request.json()
        raw_context = body.get('context') if isinstance(body, dict) else None
        try:
            if raw_context is not None and not isinstance(raw_context, dict):
                raise ValueError('invalid_context')
            context = (
                None
                if not raw_context or raw_context.get('kind') == 'freeChat'
                else validate_context(raw_context)
            )
            return rtc.bootstrap(context)
        except ValueError:
            raise HTTPException(status_code=400, detail='invalid_context') from None
        except RuntimeError:
            raise HTTPException(status_code=503, detail='rtc_not_configured') from None

    @api.post('/rtc/session/{session_id}/start')
    async def rtc_start(session_id: str, request: Request):
        require_native_client(request)
        try:
            return await rtc.start(session_id)
        except KeyError:
            raise HTTPException(status_code=404, detail='unknown_session') from None
        except RuntimeError:
            logger.warning('rtc_session_start_failed', exc_info=True)
            raise HTTPException(status_code=502, detail='rtc_start_failed') from None

    @api.post('/rtc/session/{session_id}/stop')
    async def rtc_stop(session_id: str, request: Request):
        require_native_client(request)
        try:
            await rtc.stop(session_id)
        except RuntimeError:
            # Client teardown must be idempotent. The room still closes locally
            # even if the upstream stop call is temporarily unavailable.
            logger.warning('rtc_session_stop_failed', exc_info=True)
        return {'stopped': True}

    @api.post('/translate')
    async def translate(request: Request):
        require_native_client(request)
        if upstream.missing():
            raise HTTPException(status_code=503, detail='not_configured')
        body = await request.json()
        text = body.get('text') if isinstance(body, dict) else None
        if not isinstance(text, str) or not 0 < len(text.strip()) <= 500:
            raise HTTPException(status_code=400, detail='invalid_text')
        try:
            return {'translation': await _translate_text(upstream, text.strip())}
        except Exception:
            raise HTTPException(status_code=502, detail='translation_failed') from None

    @api.post('/scene-draft')
    async def scene_draft(request: Request):
        if request.headers.get('origin') or (os.getenv('SAYPAL_CHAT_TOKEN') and not hmac.compare_digest(
                request.headers.get('authorization', ''), 'Bearer ' + os.environ['SAYPAL_CHAT_TOKEN'])):
            raise HTTPException(status_code=403, detail='forbidden')
        if upstream.missing() or not hasattr(upstream, 'generate_scene_draft'):
            raise HTTPException(status_code=503, detail='not_configured')
        body = await request.json()
        idea = body.get('idea') if isinstance(body, dict) else None
        if not isinstance(idea, str) or not 0 < len(idea.strip()) <= 160:
            raise HTTPException(status_code=400, detail='invalid_idea')
        try:
            generated = await upstream.generate_scene_draft(idea.strip())
            context = validate_context({**generated, 'kind': 'customRoleplay'})
            item = context['item']
            return {'id': 'draft-' + str(uuid4()), 'title': item['title'], 'learnerRole': item['learnerRole'],
                    'aiRole': item['aiRole'], 'situation': item['situation'], 'objectives': item['objectives'],
                    'createdAt': int(time.time() * 1000)}
        except Exception:
            raise HTTPException(status_code=502, detail='generation_failed') from None

    @api.websocket('/chat/voice')
    async def voice(ws: WebSocket):
        # Native simulator has no browser Origin. Reject cross-site websocket use.
        if ws.headers.get('origin') or (os.getenv('SAYPAL_CHAT_TOKEN') and not hmac.compare_digest(
                ws.headers.get('authorization', ''), 'Bearer ' + os.environ['SAYPAL_CHAT_TOKEN'])):
            await ws.close(code=1008)
            return
        await ws.accept()
        if upstream.missing():
            await ws.send_json({'type': 'error', 'message': '后端语音配置未完成，请检查 .env。'})
            await ws.close(code=1008)
            return
        if slots.locked():
            await ws.send_json({'type': 'error', 'message': '练习连接已满，请稍后重试。'})
            await ws.close(code=1013)
            return
        async with slots:
            await run_session(ws, upstream)

    return api


async def run_session(ws, upstream):
    history = []
    queue = None
    recognition = None
    worker = None
    size = 0
    turn = ''
    context = None
    metadata_jobs = {}
    translation_jobs = {}
    translations = {}

    def cache_translation(key, value):
        if value:
            translations[key] = value
            if len(translations) > 40:
                translations.pop(next(iter(translations)))

    async def publish_metadata(learner_text, turn_id, sentence_ids, sentences):
        try:
            async with asyncio.timeout(13):
                result = await upstream.reply_metadata(
                    learner_text=learner_text, reply=' '.join(sentences), segments=sentences)
            items = []
            for index, (sentence_id, sentence) in enumerate(zip(sentence_ids, sentences)):
                if index < len(result['translations']):
                    value = result['translations'][index].strip()
                    if value:
                        cache_translation((sentence_id, sentence), value)
                        items.append({'id': sentence_id, 'translation': value})
            await ws.send_json({'type': 'reply_meta', 'userId': turn_id, 'items': items,
                                'correction': result['correction']})
        except Exception:
            # Optional text must never end the voice turn or close the socket.
            return

    async def publish_translation(key, metadata):
        message_id, text = key
        try:
            if metadata is not None and key not in translations:
                # Give an already-running batch a short head start. A slow
                # correction should not delay a translation the user asked for.
                with contextlib.suppress(TimeoutError):
                    await asyncio.wait_for(asyncio.shield(metadata), timeout=1)
            translated = translations.get(key)
            if translated is None:
                translated = await _translate_text(upstream, text)
                cache_translation(key, translated)
            await ws.send_json({'type': 'reply_translation', 'id': message_id,
                                'translation': translated})
        except Exception:
            with contextlib.suppress(Exception):
                await ws.send_json({'type': 'translation_error', 'id': message_id})

    def split_ready_sentences(buffer, *, flush=False):
        """Flush short English sentences early, like the reference voice chain."""
        ready = []
        while True:
            matched = re.match(r'^\s*(.+?[.!?])(?=\s|$)(.*)$', buffer, re.DOTALL)
            if not matched:
                break
            sentence = matched.group(1).strip()
            buffer = matched.group(2)
            if sentence:
                ready.append(sentence)
        # A model occasionally delays punctuation. Keep first speech responsive
        # without cutting in the middle of a short word.
        if len(buffer) >= 72:
            split_at = max(buffer.rfind(' ', 0, 72), buffer.rfind(',', 0, 72))
            if split_at > 15:
                ready.append(buffer[:split_at + 1].strip())
                buffer = buffer[split_at + 1:]
        if flush and buffer.strip():
            ready.append(buffer.strip())
            buffer = ''
        return ready, buffer

    async def respond_stream(text, turn_id):
        response_id = str(uuid4())
        sentence_ids, sentences = [], []
        tts_queue = asyncio.Queue()
        # Some models deliver several complete sentences in one SSE delta. Keep
        # the first one immediate, then reveal any burst one by one so the UI
        # remains visibly streamed instead of appearing as one large reply.
        try:
            segment_gap = max(0.0, min(float(os.getenv('VOICE_STREAM_SEGMENT_GAP_SECONDS', '0.55')), 2.0))
        except ValueError:
            segment_gap = 0.55
        last_segment_at = None

        async def synthesize_sentences():
            while True:
                item = await tts_queue.get()
                if item is None:
                    return
                segment_id, sentence = item
                try:
                    audio = await upstream.speak(sentence)
                    await ws.send_json({'type': 'audio', 'id': segment_id, 'data': audio})
                except Exception:
                    await ws.send_json({'type': 'error', 'message': '有一句语音播放生成失败，文字仍可阅读。'})

        tts_worker = asyncio.create_task(synthesize_sentences())

        async def emit_sentence(sentence):
            nonlocal last_segment_at
            if last_segment_at is not None:
                remaining = segment_gap - (asyncio.get_running_loop().time() - last_segment_at)
                if remaining > 0:
                    await asyncio.sleep(remaining)
            segment_id = f'{response_id}-{len(sentence_ids)}'
            sentence_ids.append(segment_id)
            sentences.append(sentence)
            await ws.send_json({'type': 'reply_segment', 'id': segment_id,
                                'userId': turn_id, 'text': sentence})
            last_segment_at = asyncio.get_running_loop().time()
            await tts_queue.put((segment_id, sentence))

        try:
            await ws.send_json({'type': 'transcript', 'id': turn_id, 'text': text})
            pending = history + [{'role': 'user', 'content': text}]
            buffer = ''
            context_prompt = prompt_for(context) if context else ''
            try:
                stream = (upstream.stream_reply(pending, context_prompt)
                          if context else upstream.stream_reply(pending))
                async for delta in stream:
                    buffer += delta
                    ready, buffer = split_ready_sentences(buffer)
                    for sentence in ready:
                        await emit_sentence(sentence)
            except Exception:
                # Some compatible Ark endpoints support ordinary chat but
                # reject or prematurely close SSE. If no visible segment was
                # emitted yet, retry once through the non-streaming endpoint.
                # Never fallback after a partial answer, which would duplicate
                # content and charge for a second complete response.
                if sentence_ids or not hasattr(upstream, 'reply'):
                    raise
                fallback = (await upstream.reply(pending, context_prompt)
                            if context else await upstream.reply(pending))
                buffer = fallback.get('reply', '') if isinstance(fallback, dict) else ''
            ready, _ = split_ready_sentences(buffer, flush=True)
            for sentence in ready:
                await emit_sentence(sentence)
            if not sentences:
                raise ValueError('empty_stream_reply')
            history[:] = (pending + [{'role': 'assistant', 'content': ' '.join(sentences)}])[-16:]
            if context:
                await ws.send_json(progress_after_turn(context, text))
            if len(metadata_jobs) < 2:
                keys = set(zip(sentence_ids, sentences))
                job = asyncio.create_task(publish_metadata(text, turn_id, sentence_ids, sentences))
                metadata_jobs[job] = keys
                job.add_done_callback(metadata_jobs.pop)
        finally:
            await tts_queue.put(None)
            await asyncio.gather(tts_worker, return_exceptions=True)

    async def respond(text, turn_id):
        try:
            if not text.strip():
                await ws.send_json({'type': 'error', 'message': '没有听清，请再说一次。'})
                return
            if hasattr(upstream, 'stream_reply'):
                await respond_stream(text, turn_id)
                return
            await ws.send_json({'type': 'transcript', 'id': turn_id, 'text': text})
            pending = history + [{'role': 'user', 'content': text}]
            result = await upstream.reply(pending)
            reply_id = str(uuid4())
            history[:] = (pending + [{'role': 'assistant', 'content': result['reply']}])[-16:]
            await ws.send_json({'type': 'reply', 'id': reply_id, 'userId': turn_id, **result})
            if context:
                await ws.send_json(progress_after_turn(context, text))
            try:
                audio = await upstream.speak(result['reply'])
                await ws.send_json({'type': 'audio', 'id': reply_id, 'data': audio})
            except Exception:
                await ws.send_json({'type': 'error', 'message': '语音播放生成失败，文字回复已保留。'})
        except Exception:
            await ws.send_json({'type': 'error', 'message': '语音或 AI 服务暂不可用，请检查配置后重试。'})
        finally:
            with contextlib.suppress(Exception):
                await ws.send_json({'type': 'done'})

    async def finish(asr, turn_id):
        try:
            # ASR can need a few seconds to flush an utterance after its final
            # PCM frame; cancelling it at 15 s caused completed speech to be
            # discarded before its definite result arrived.
            text = await asyncio.wait_for(asr, timeout=45)
        except ValueError as error:
            # The numeric code is safe to expose and lets local development
            # distinguish account/resource rejection from microphone issues.
            detail = str(error)
            logger.warning(
                'voice_turn_failed stage=asr_rejected code=%s',
                detail if detail.startswith('asr_rejected_') else 'invalid_result',
            )
            if detail == 'asr_rejected_45000292':
                message = '语音识别额度已用完，请让家长在服务控制台处理后再试。'
            elif detail.startswith('asr_rejected_'):
                message = '语音识别服务拒绝了本次请求（%s），请检查后端配置。' % detail
            else:
                message = '语音识别返回的数据无效，请重试。'
            await ws.send_json({'type': 'error', 'message': message})
            await ws.send_json({'type': 'done'})
            return
        except TimeoutError:
            logger.warning('voice_turn_failed stage=asr_timeout')
            await ws.send_json({'type': 'error', 'message': '语音识别等待超时，请再短一点说一遍。'})
            await ws.send_json({'type': 'done'})
            return
        except Exception:
            logger.warning('voice_turn_failed stage=asr_transport')
            await ws.send_json({'type': 'error', 'message': '语音识别失败，请重试。'})
            await ws.send_json({'type': 'done'})
            return
        await respond(text, turn_id)

    async def partial(text):
        await ws.send_json({'type': 'partial', 'text': text})

    try:
        await ws.send_json({'type': 'ready'})
        # Session has a hard lifetime. Audio is transient; nothing is persisted.
        # Idle budget covers a child thinking before the next turn; the client
        # keeps the socket alive with pings, which do not reset this timeout.
        async with asyncio.timeout(1800):
            while True:
                event = await asyncio.wait_for(ws.receive(), timeout=300)
                if event['type'] == 'websocket.disconnect':
                    break
                data = event.get('bytes')
                if data is not None:
                    if queue is None or len(data) % 2 or len(data) > 65536:
                        raise ValueError('invalid_audio')
                    size += len(data)
                    if size > 16000 * 2 * 30:
                        raise ValueError('recording_too_long')
                    queue.put_nowait(data)
                    continue
                raw = event.get('text', '')
                if len(raw) > 4096:
                    raise ValueError('message_too_large')
                try:
                    command = json.loads(raw)
                except json.JSONDecodeError:
                    raise ValueError('invalid_message') from None
                kind = command.get('type')
                busy = worker is not None and not worker.done()
                # State mismatches are usually a delayed/duplicated command from
                # a well-meaning client. Answer softly instead of dropping a
                # child's whole session; only malformed protocol closes here.
                if kind == 'configure':
                    if queue is not None or busy:
                        await ws.send_json({'type': 'error', 'message': '请等这一轮结束后再切换练习。'})
                    else:
                        try:
                            context = validate_context(command.get('context'))
                        except ValueError:
                            await ws.send_json({'type': 'error', 'message': '练习内容无效，请返回重新选择。'})
                            continue
                        history.clear()
                        await ws.send_json({'type': 'configured', 'label': '练习已准备好'})
                elif kind == 'start':
                    if queue is not None:
                        await ws.send_json({'type': 'error', 'message': '已经在录音了，请先说完这一句。'})
                    elif busy:
                        await ws.send_json({'type': 'error', 'message': '请等小蓝说完再开始。'})
                    else:
                        turn, size = str(uuid4()), 0
                        queue = asyncio.Queue(maxsize=512)
                        recognition = asyncio.create_task(upstream.recognize(queue, partial))
                elif kind == 'end':
                    if queue is not None:
                        queue.put_nowait(None)
                        queue = None
                        worker = asyncio.create_task(finish(recognition, turn))
                    elif not busy:
                        await ws.send_json({'type': 'error', 'message': '还没有开始录音哦。'})
                elif kind == 'text':
                    if queue is not None or busy:
                        await ws.send_json({'type': 'error', 'message': '请等小蓝说完。'})
                    else:
                        text = command.get('text')
                        if not isinstance(text, str) or not 0 < len(text.strip()) <= 1000:
                            raise ValueError('invalid_text')
                        worker = asyncio.create_task(respond(text.strip(), str(uuid4())))
                elif kind == 'translate':
                    message_id = command.get('id')
                    text = command.get('text')
                    if (not isinstance(message_id, str) or not message_id or
                            not isinstance(text, str) or not 0 < len(text.strip()) <= 500):
                        raise ValueError('invalid_translation')
                    key = message_id[:160], text.strip()
                    if key in translation_jobs:
                        continue
                    if len(translation_jobs) >= 4:
                        await ws.send_json({
                            'type': 'translation_error',
                            'id': key[0],
                        })
                        continue
                    metadata = next((job for job, keys in metadata_jobs.items() if key in keys), None)
                    job = asyncio.create_task(publish_translation(key, metadata))
                    translation_jobs[key] = job
                    job.add_done_callback(lambda _, key=key: translation_jobs.pop(key, None))
                else:
                    raise ValueError('invalid_state')
    except WebSocketDisconnect:
        pass
    except Exception:
        with contextlib.suppress(Exception):
            await ws.send_json({'type': 'error', 'message': '连接已结束，请重新连接。'})
    finally:
        tasks = [task for task in (worker, recognition) if task is not None]
        tasks.extend(metadata_jobs)
        tasks.extend(translation_jobs.values())
        for task in tasks:
            task.cancel()
        await asyncio.gather(*tasks, return_exceptions=True)
        with contextlib.suppress(Exception):
            await ws.close()


app = create_app()

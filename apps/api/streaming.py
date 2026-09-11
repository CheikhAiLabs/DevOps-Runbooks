"""Incremental model SSE decoding, citation filtering and disconnect handling."""
from __future__ import annotations

import asyncio
import contextlib
import json
import re

import httpx
from starlette.responses import StreamingResponse


class EventStreamResponse(StreamingResponse):
    """Listen for ASGI disconnects even while no model tokens are available."""

    async def __call__(self, scope, receive, send):
        sender = asyncio.create_task(self.stream_response(send))
        disconnect = asyncio.create_task(self.listen_for_disconnect(receive))
        try:
            done, _ = await asyncio.wait({sender, disconnect}, return_when=asyncio.FIRST_COMPLETED)
            for task in done:
                task.result()
        except OSError:
            pass  # The socket can close before the ASGI disconnect notification.
        finally:
            for task in (sender, disconnect):
                task.cancel()
            await asyncio.gather(sender, disconnect, return_exceptions=True)
            await self.body_iterator.aclose()
            if self.background is not None:
                await self.background()


def encode_event(event: str, data: dict) -> str:
    return f"event: {event}\ndata: {json.dumps(data, ensure_ascii=False)}\n\n"


class CitationFilter:
    """Hold only possible citations, including markers split across chunks."""

    marker = re.compile(r"\[\s*sources?\s*:?\s*\d+(?:\s*[,;–-]\s*\d+)*\s*\]", re.I)

    def __init__(self):
        self.pending = ""

    def possible_marker(self) -> bool:
        body = self.pending[1:].lstrip().lower()
        for word in ("sources", "source"):
            if word.startswith(body):
                return True
            if body.startswith(word) and re.fullmatch(r"\s*:?\s*[\d\s,;–-]*", body[len(word):]):
                return True
        return False

    def feed(self, text: str) -> str:
        output = []
        for char in text:
            if not self.pending:
                if char == "[":
                    self.pending = char
                else:
                    output.append(char)
                continue
            self.pending += char
            if self.marker.fullmatch(self.pending):
                self.pending = ""
            elif not self.possible_marker():
                if char == "[":
                    output.append(self.pending[:-1])
                    self.pending = "["
                else:
                    output.append(self.pending)
                    self.pending = ""
            elif len(self.pending) > 256:
                raise ValueError("Overlong citation marker")
        return "".join(output)

    def finish(self) -> str:
        # Never emit an incomplete citation. Preserve an ordinary lone bracket.
        tail = self.pending if self.pending == "[" else ""
        self.pending = ""
        return tail


async def openai_tokens(url: str, payload: dict, metadata: dict):
    async with httpx.AsyncClient(timeout=httpx.Timeout(240.0, connect=10.0)) as client:
        async with client.stream("POST", url, json={**payload, "stream": True}) as response:
            response.raise_for_status()
            if not response.headers.get("content-type", "").startswith("text/event-stream"):
                raise ValueError("Model did not return an event stream")
            data_lines = []
            event_size = 0
            async for line in response.aiter_lines():
                if line:
                    if line.startswith("data:"):
                        data_lines.append(line[5:].removeprefix(" "))
                        event_size += len(line)
                        if event_size > 65536:
                            raise ValueError("Model event exceeded the size limit")
                    continue
                if not data_lines:
                    continue
                raw = "\n".join(data_lines)
                data_lines = []
                event_size = 0
                if raw.strip() == "[DONE]":
                    return
                data = json.loads(raw)
                if data.get("error"):
                    raise ValueError("Model returned an error event")
                for choice in data.get("choices", []):
                    if choice.get("index", 0) != 0:
                        continue
                    if choice.get("finish_reason"):
                        metadata["finish_reason"] = choice["finish_reason"]
                    content = (choice.get("delta") or {}).get("content")
                    if isinstance(content, str) and content:
                        yield content
            if "\n".join(data_lines).strip() != "[DONE]":
                raise ValueError("Model stream ended before its completion marker")


async def heartbeat_events(events):
    """Keep idle retrieval/thinking connections alive with SSE comments."""
    iterator = events.__aiter__()
    pending = None
    try:
        while True:
            if pending is None:
                pending = asyncio.create_task(anext(iterator))
            done, _ = await asyncio.wait({pending}, timeout=10)
            if not done:
                yield ": keep-alive\n\n"
                continue
            try:
                event, data = pending.result()
            except StopAsyncIteration:
                return
            pending = None
            yield encode_event(event, data)
    finally:
        if pending is not None:
            pending.cancel()
            with contextlib.suppress(asyncio.CancelledError, StopAsyncIteration):
                await pending
        await iterator.aclose()

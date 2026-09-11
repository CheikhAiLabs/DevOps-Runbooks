import { MAX_FILES, MAX_EXTRACTED_CHARS } from "./files";
import { readLimitedBody } from "./request-body";

async function askBody(request) {
  let body;
  try {
    const raw = await readLimitedBody(request, 512 * 1024);
    body = JSON.parse(new TextDecoder().decode(raw));
  } catch (error) {
    throw Object.assign(new Error("The message is invalid or too large."), { status: error.status || 400 });
  }
  const question = typeof body?.question === "string" ? body.question.trim() : "";
  const imageText = typeof body?.image_text === "string" ? body.image_text.trim() : "";
  const files = body?.files ?? [];
  if (question.length > 4000 || !Array.isArray(files) || files.length > MAX_FILES ||
      files.some(file => !file || typeof file.name !== "string" || typeof file.text !== "string" || file.text.length > MAX_EXTRACTED_CHARS)) {
    throw Object.assign(new Error("Use a question of up to 4,000 characters and at most five files."), { status: 400 });
  }
  if (!question && !imageText && !files.some(file => file.text.trim())) {
    throw Object.assign(new Error("Add a question or a file with readable content."), { status: 400 });
  }
  return { question, files, image_text: imageText || null, history: Array.isArray(body?.history) ? body.history.slice(-6) : [] };
}

export async function proxyAsk(request, streaming = false) {
  const abort = new AbortController();
  try {
    const body = await askBody(request);
    const upstream = await fetch(`http://127.0.0.1:8000/ask${streaming ? "/stream" : ""}`, {
      method: "POST", headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body), cache: "no-store",
      signal: AbortSignal.any([request.signal, abort.signal, AbortSignal.timeout(300000)]),
    });
    if (!upstream.ok) {
      const data = await upstream.json().catch(() => null);
      return Response.json({ error: typeof data?.detail === "string" ? data.detail : "The answer could not be generated. Please try again." }, { status: upstream.status });
    }
    if (!streaming) return Response.json(await upstream.json());
    if (!upstream.body || !upstream.headers.get("content-type")?.startsWith("text/event-stream")) {
      abort.abort();
      return Response.json({ error: "The answer service did not return a stream." }, { status: 502 });
    }
    const reader = upstream.body.getReader();
    // Pull forwards one received chunk at a time and respects downstream backpressure.
    const stream = new ReadableStream({
      async pull(controller) {
        try {
          const { value, done } = await reader.read();
          if (done) {
            reader.releaseLock();
            controller.close();
          } else controller.enqueue(value);
        } catch (error) {
          abort.abort();
          reader.releaseLock();
          controller.error(error);
        }
      },
      async cancel(reason) {
        abort.abort(reason);
        await reader.cancel(reason).catch(() => {});
      },
    });
    return new Response(stream, { headers: {
      "Content-Type": "text/event-stream; charset=utf-8",
      "Cache-Control": "no-cache, no-transform",
      "X-Accel-Buffering": "no",
    } });
  } catch (error) {
    abort.abort();
    const status = error.status || (error.name === "AbortError" ? 499 : error.name === "TimeoutError" ? 504 : 502);
    return Response.json({ error: error.status ? error.message : "The answer service is unavailable. Please try again." }, { status });
  }
}

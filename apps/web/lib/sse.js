// Decode SSE frames across arbitrary network and UTF-8 boundaries.
export async function* readEvents(response, signal) {
  if (!response.body || !response.headers.get("content-type")?.startsWith("text/event-stream")) {
    throw new Error("The answer service did not return a stream.");
  }
  const reader = response.body.getReader();
  const decoder = new TextDecoder("utf-8", { fatal: true });
  let buffer = "";
  let event = "message";
  let data = [];
  let size = 0;
  const cancel = () => { reader.cancel(signal.reason).catch(() => {}); };
  signal.addEventListener("abort", cancel, { once: true });
  function line(value) {
    value = value.replace(/\r$/, "");
    if (!value) {
      const result = data.length ? { event, data: JSON.parse(data.join("\n")) } : null;
      event = "message";
      data = [];
      size = 0;
      return result;
    }
    if (value.startsWith(":")) return null;
    size += value.length;
    if (size > 65536) throw new Error("The answer stream contains an oversized event.");
    if (value.startsWith("event:")) event = value.slice(6).trim();
    if (value.startsWith("data:")) data.push(value.slice(5).replace(/^ /, ""));
    return null;
  }
  try {
    while (true) {
      signal.throwIfAborted();
      const { value, done } = await reader.read();
      signal.throwIfAborted();
      buffer += done ? decoder.decode() : decoder.decode(value, { stream: true });
      let newline;
      while ((newline = buffer.indexOf("\n")) !== -1) {
        const result = line(buffer.slice(0, newline));
        buffer = buffer.slice(newline + 1);
        if (result) yield result;
      }
      if (buffer.length > 65536) throw new Error("The answer stream contains an oversized line.");
      if (done) {
        if (buffer) line(buffer);
        const result = line("");
        if (result) yield result;
        return;
      }
    }
  } finally {
    signal.removeEventListener("abort", cancel);
    await reader.cancel().catch(() => {});
    reader.releaseLock();
  }
}

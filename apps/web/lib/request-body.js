// Enforce actual bytes read, including requests without Content-Length.
export async function readLimitedBody(request, maxBytes) {
  if (Number(request.headers.get("content-length")) > maxBytes) {
    throw Object.assign(new Error("The upload is too large."), { status: 413 });
  }
  if (!request.body) return new Uint8Array();
  const reader = request.body.getReader();
  const chunks = [];
  let length = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      length += value.byteLength;
      if (length > maxBytes) {
        await reader.cancel();
        throw Object.assign(new Error("The upload is too large."), { status: 413 });
      }
      chunks.push(value);
    }
  } finally {
    reader.releaseLock();
  }
  const result = new Uint8Array(length);
  let offset = 0;
  for (const chunk of chunks) {
    result.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return result;
}

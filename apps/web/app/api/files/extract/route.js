import { MAX_FILE_BYTES, validateFile } from "../../../../lib/files";
import { readLimitedBody } from "../../../../lib/request-body";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function POST(request) {
  try {
    const contentType = request.headers.get("content-type") || "";
    if (!contentType.startsWith("multipart/form-data;")) {
      return Response.json({ error: "Send the file as form data." }, { status: 415 });
    }
    // Each attachment is uploaded separately, below the existing Nginx 12m limit.
    const raw = await readLimitedBody(request, MAX_FILE_BYTES + 65536);
    let incoming;
    try {
      incoming = await new Response(raw, { headers: { "Content-Type": contentType } }).formData();
    } catch {
      return Response.json({ error: "The upload could not be read." }, { status: 400 });
    }
    const entries = Array.from(incoming.entries());
    const file = incoming.get("file");
    if (entries.length !== 1 || !file || typeof file === "string") {
      return Response.json({ error: "Attach one file per upload." }, { status: 400 });
    }
    const error = validateFile(file);
    if (error) return Response.json({ error }, { status: 400 });

    const outgoing = new FormData();
    outgoing.append("file", file, file.name);
    const upstream = await fetch("http://127.0.0.1:8000/files/extract", {
      method: "POST", body: outgoing, cache: "no-store",
      signal: AbortSignal.any([request.signal, AbortSignal.timeout(120000)]),
    });
    return new Response(await upstream.text(), {
      status: upstream.status,
      headers: { "Content-Type": "application/json" },
    });
  } catch (error) {
    const status = error.status || (error.name === "AbortError" ? 499 : error.name === "TimeoutError" ? 504 : 502);
    return Response.json({ error: status === 413 ? error.message : "The file could not be processed. Please try again." }, { status });
  }
}

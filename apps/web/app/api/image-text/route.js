export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function POST(request) {
  try {
    const incoming = await request.formData();
    const file = incoming.get("file");

    if (!file || typeof file === "string") {
      return Response.json({ error: "Image is required." }, { status: 400 });
    }
    if (file.size > 10 * 1024 * 1024) {
      return Response.json({ error: "Image must be 10 MB or smaller." }, { status: 413 });
    }

    const outgoing = new FormData();
    outgoing.append("file", file, file.name || "image.png");

    const upstream = await fetch("http://127.0.0.1:8000/image-text", {
      method: "POST",
      body: outgoing,
      cache: "no-store",
      signal: AbortSignal.any([request.signal, AbortSignal.timeout(120000)]),
    });

    return new Response(await upstream.text(), {
      status: upstream.status,
      headers: {
        "Content-Type": upstream.headers.get("content-type") || "application/json",
      },
    });
  } catch (error) {
    return Response.json({
      error: "Image processing failed.",
      detail: error?.message || "Unknown error",
    }, { status: 500 });
  }
}

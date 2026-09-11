import { proxyAsk } from "../../../../lib/ask-proxy";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function POST(request) {
  return proxyAsk(request, true);
}

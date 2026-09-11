"use client";

import { useEffect, useRef, useState } from "react";
import { Check, Copy } from "lucide-react";

export default function CopyButton({ text, label = "Copy answer" }) {
  const [status, setStatus] = useState("");
  const timer = useRef(null);
  useEffect(() => {
    return () => clearTimeout(timer.current);
  }, []);
  async function copy() {
    clearTimeout(timer.current);
    try {
      await navigator.clipboard.writeText(text);
      setStatus("copied");
    } catch {
      setStatus("failed");
    }
    timer.current = setTimeout(() => setStatus(""), 1500);
  }
  return (
    <button type="button" onClick={copy} aria-label={label}
      className="flex shrink-0 items-center gap-1.5 rounded-lg px-2 py-1.5 text-[11px] text-white/50 transition hover:bg-white/5 hover:text-white/85">
      {status === "copied" ? <Check size={12} /> : <Copy size={12} />}
      <span aria-live="polite">{status === "copied" ? "Copied" : status === "failed" ? "Copy failed" : "Copy"}</span>
    </button>
  );
}

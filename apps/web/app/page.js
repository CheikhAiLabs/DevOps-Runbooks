"use client";

import {
  useEffect,
  useRef,
  useState,
} from "react";

import MarkdownAnswer from "./components/markdown-answer";
import CopyButton from "./components/copy-button";
import { readEvents } from "../lib/sse";

import {
  ArrowDown,
  ArrowUp,
  Loader2,
  BookOpen,
  ChevronRight,
  ExternalLink,
  HardDrive,
  Mic,
  Network,
  Paperclip,
  Plus,
  Server,
  ShieldCheck,
  Sparkles,
  Square,
  Terminal,
} from "lucide-react";
import AttachmentCard from "./components/attachment-card";
import { FILE_ACCEPT, MAX_FILES, MAX_FILE_CONTEXT_CHARS, fileKind, validateFile, errorMessage } from "../lib/files";


const suggestions = [
  {
    icon:
      Server,

    title:
      "Boot failure",

    prompt:
      "A bare metal Linux server no longer boots after a kernel update. Give me a safe diagnostic procedure from the console.",
  },

  {
    icon:
      HardDrive,

    title:
      "Storage & LVM",

    prompt:
      "A Linux server reports no space left on device although the volume group may still have free capacity. How should I diagnose it?",
  },

  {
    icon:
      Network,

    title:
      "Network",

    prompt:
      "A Linux server can reach its local subnet but cannot reach the internet. Give me a systematic production troubleshooting procedure.",
  },

  {
    icon:
      ShieldCheck,

    title:
      "SSH hardening",

    prompt:
      "Give me a production-grade checklist to harden SSH access on a Linux bare metal server.",
  },
];


function Brand() {

  return (
    <div className="flex items-center gap-3">

      <div className="grid h-9 w-9 place-items-center rounded-xl border border-white/10 bg-white/[.055]">

        <Terminal
          size={17}
        />

      </div>

      <div>

        <div className="flex items-center gap-2">

          <span className="text-[15px] font-semibold">
            Runbook AI
          </span>

          <span className="rounded-full border border-[#9fe870]/20 bg-[#9fe870]/10 px-1.5 py-0.5 text-[9px] font-bold uppercase tracking-[.13em] text-[#aff085]">
            Private
          </span>

        </div>

        <p className="mt-0.5 text-[11px] text-white/35">
          Linux · Bare Metal · Infrastructure
        </p>

      </div>

    </div>
  );
}


function StatusPill() {

  return (
    <div className="flex items-center gap-2 rounded-full border border-white/[.07] bg-white/[.035] px-3 py-1.5 text-[11px] text-white/45">

      <span className="relative flex h-2 w-2">

        <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-[#9fe870] opacity-20" />

        <span className="relative inline-flex h-2 w-2 rounded-full bg-[#9fe870]" />

      </span>

      Private workspace

    </div>
  );
}


function SourceCard({
  source,
}) {

  return (
    <a
      href={source.url}
      target="_blank"
      rel="noreferrer"
      className="group flex min-w-[250px] max-w-[315px] flex-1 flex-col justify-between rounded-xl border border-white/[.075] bg-white/[.025] p-3.5 transition hover:border-white/[.15] hover:bg-white/[.045]"
    >

      <div>

        <div className="mb-2 flex items-center justify-between">

          <span className="font-mono text-[10px] uppercase tracking-[.12em] text-[#9fe870]/75">
            Evidence
          </span>

          <ExternalLink
            size={12}
            className="text-white/25"
          />

        </div>

        <div className="line-clamp-2 text-[13px] font-medium leading-5 text-white/80">
          {source.title}
        </div>

        {
          source.section
          &&
          (
            <div className="mt-1.5 line-clamp-1 text-[11px] text-white/35">
              {source.section}
            </div>
          )
        }

      </div>

    </a>
  );
}


export default function Home() {
  const [question, setQuestion] = useState("");
  const [messages, setMessages] = useState([]);
  const [attachments, setAttachments] = useState([]);
  const [loading, setLoading] = useState(false);
  const [phase, setPhase] = useState("");
  const [listening, setListening] = useState(false);
  const [notice, setNotice] = useState("");
  const [dragging, setDragging] = useState(false);
  const [nearBottom, setNearBottom] = useState(true);
  const [composerHeight, setComposerHeight] = useState(180);
  const textareaRef = useRef(null);
  const inputRef = useRef(null);
  const composerRef = useRef(null);
  const bottomRef = useRef(null);
  const recognitionRef = useRef(null);
  const activeRef = useRef(null);
  const previewsRef = useRef(new Set());
  const followBottomRef = useRef(true);
  const dragDepthRef = useRef(0);

  useEffect(() => {
    textareaRef.current?.focus();
    const previews = previewsRef.current;
    return () => {
      clearTimeout(activeRef.current?.flushTimer);
      activeRef.current?.controller.abort();
      if (recognitionRef.current) {
        recognitionRef.current.onresult = null;
        recognitionRef.current.abort();
      }
      previews.forEach(url => URL.revokeObjectURL(url));
      previews.clear();
    };
  }, []);

  useEffect(() => {
    const observer = new ResizeObserver(entries => {
      setComposerHeight(entries[0].target.getBoundingClientRect().height);
    });
    if (composerRef.current) observer.observe(composerRef.current);
    return () => observer.disconnect();
  }, []);

  useEffect(() => {
    function trackScroll() {
      const close = document.documentElement.scrollHeight - window.scrollY - window.innerHeight < 160;
      followBottomRef.current = close;
      setNearBottom(close);
    }
    window.addEventListener("scroll", trackScroll, { passive: true });
    return () => window.removeEventListener("scroll", trackScroll);
  }, []);

  useEffect(() => {
    if (followBottomRef.current) bottomRef.current?.scrollIntoView({ block: "end" });
  }, [messages, phase, composerHeight]);

  useEffect(() => {
    const field = textareaRef.current;
    if (!field) return;
    field.style.height = "auto";
    field.style.height = `${Math.min(field.scrollHeight, 180)}px`;
  }, [question]);

  function stopVoice() {
    const recognition = recognitionRef.current;
    recognitionRef.current = null;
    if (recognition) {
      recognition.onresult = null;
      recognition.abort();
    }
    setListening(false);
  }

  function stopGeneration() {
    const active = activeRef.current;
    if (!active) return;
    activeRef.current = null;
    clearTimeout(active.flushTimer);
    active.buffer = "";
    active.controller.abort();
    setLoading(false);
    setPhase("");
    setMessages(current => current.map(message => {
      if (message.id === active.assistantId) {
        return { ...message, pending: false, stopped: true, error: true, notice: "Response stopped." };
      }
      if (message.id === active.userId) {
        return { ...message, files: message.files.map(file =>
          ["queued", "reading"].includes(file.status)
            ? { ...file, status: "error", error: "File reading stopped." } : file
        ) };
      }
      return message;
    }));
  }

  function newChat() {
    stopGeneration();
    stopVoice();
    previewsRef.current.forEach(url => URL.revokeObjectURL(url));
    previewsRef.current.clear();
    setMessages([]);
    setAttachments([]);
    setQuestion("");
    setNotice("");
    followBottomRef.current = true;
    textareaRef.current?.focus();
  }

  function addFiles(files) {
    const added = [];
    const errors = [];
    for (const file of Array.from(files)) {
      if (attachments.length + added.length >= MAX_FILES) {
        errors.push(`Attach at most ${MAX_FILES} files per message.`);
        break;
      }
      const error = validateFile(file);
      if (error) {
        errors.push(`${file.name}: ${error}`);
        continue;
      }
      const kind = fileKind(file.name);
      const preview = kind === "image" ? URL.createObjectURL(file) : null;
      if (preview) previewsRef.current.add(preview);
      added.push({ id: crypto.randomUUID(), file, name: file.name, size: file.size, kind, preview });
    }
    setAttachments(current => [...current, ...added]);
    setNotice(errors.join(" "));
    textareaRef.current?.focus();
  }

  function removeFile(id) {
    const attachment = attachments.find(file => file.id === id);
    if (attachment?.preview) {
      URL.revokeObjectURL(attachment.preview);
      previewsRef.current.delete(attachment.preview);
    }
    setAttachments(current => current.filter(file => file.id !== id));
  }

  function toggleVoice() {
    if (recognitionRef.current) {
      recognitionRef.current.stop();
      return;
    }
    const Recognition = window.SpeechRecognition || window.webkitSpeechRecognition;
    if (!Recognition) {
      setNotice("Voice dictation is not supported by this browser.");
      return;
    }
    const recognition = new Recognition();
    const prefix = question.trim() ? `${question.trim()} ` : "";
    recognitionRef.current = recognition;
    recognition.lang = navigator.language || "fr-FR";
    recognition.continuous = true;
    recognition.interimResults = true;
    recognition.onstart = () => {
      if (recognitionRef.current !== recognition) return;
      setListening(true);
      setNotice("");
    };
    recognition.onend = () => {
      if (recognitionRef.current !== recognition) return;
      recognitionRef.current = null;
      setListening(false);
    };
    recognition.onerror = event => {
      if (recognitionRef.current !== recognition) return;
      setNotice(`Voice dictation: ${event.error}`);
      stopVoice();
    };
    recognition.onresult = event => {
      if (recognitionRef.current !== recognition) return;
      const transcript = Array.from(event.results).map(result => result[0].transcript).join(" ");
      setQuestion(`${prefix}${transcript}`.slice(0, 4000));
    };
    try {
      recognition.start();
    } catch {
      stopVoice();
      setNotice("Unable to start voice dictation. Check microphone access.");
    }
  }

  function historyContent(message) {
    if (!message.files?.length) return message.content.slice(0, 4000);
    const excerpts = message.files.filter(file => file.text).map(file =>
      `File ${file.name}: ${file.text.slice(0, Math.floor(1800 / message.files.length))}`
    );
    return [message.content.slice(0, 2000), ...excerpts].join("\n\n").slice(0, 4000);
  }

  async function ask(text) {
    const q = (text ?? question).trim();
    if (activeRef.current || (!q && !attachments.length)) return;
    const files = [...attachments];
    const controller = new AbortController();
    const userId = crypto.randomUUID();
    const assistantId = crypto.randomUUID();
    const active = { controller, userId, assistantId, buffer: "", flushTimer: null, hasVisibleText: false };
    activeRef.current = active;
    const history = messages.filter(message => !message.pending && (!message.error || (message.stopped && message.content)))
      .slice(-6).map(message => ({ role: message.role, content: historyContent(message) }));

    stopVoice();
    setQuestion("");
    setAttachments([]);
    setNotice("");
    setLoading(true);
    setPhase(files.length ? "Reading your files…" : "Preparing your answer…");
    followBottomRef.current = true;
    setMessages(current => [...current,
      { id: userId, role: "user", content: q, files: files.map(({ file, ...metadata }) => ({ ...metadata, status: "queued" })) },
      { id: assistantId, role: "assistant", content: "", pending: true },
    ]);

    const flushTokens = () => {
      clearTimeout(active.flushTimer);
      active.flushTimer = null;
      if (activeRef.current !== active || !active.buffer) return;
      const content = active.buffer;
      active.buffer = "";
      setMessages(current => current.map(message => message.id === assistantId
        ? { ...message, content: message.content + content } : message));
    };

    const updateFile = (id, update) => {
      if (activeRef.current !== active) return;
      setMessages(current => current.map(message => message.id === userId
        ? { ...message, files: message.files.map(file => file.id === id ? { ...file, ...update } : file) }
        : message));
    };

    try {
      const extracted = [];
      for (const [index, file] of files.entries()) {
        controller.signal.throwIfAborted();
        setPhase(`Reading file ${index + 1} of ${files.length}…`);
        updateFile(file.id, { status: "reading" });
        try {
          const form = new FormData();
          form.append("file", file.file);
          const response = await fetch("/api/files/extract", {
            method: "POST", body: form, signal: controller.signal,
          });
          const data = await response.json().catch(() => null);
          controller.signal.throwIfAborted();
          if (!response.ok || !data || typeof data.text !== "string") {
            throw new Error(errorMessage(data, "The file could not be read."));
          }
          const warnings = [...(data.warnings || [])];
          if (data.text.length > Math.floor(MAX_FILE_CONTEXT_CHARS / files.length)) {
            warnings.push("Only part of this file can be used in this answer.");
          }
          extracted.push({ name: data.name, size: data.size, kind: data.kind, text: data.text, truncated: data.truncated, warnings });
          updateFile(file.id, { status: "ready", text: data.text, warnings });
        } catch (error) {
          controller.signal.throwIfAborted();
          const detail = error.message || "The file could not be read.";
          updateFile(file.id, { status: "error", error: detail });
          extracted.push({ name: file.name, size: file.size, kind: file.kind === "code" ? "text" : file.kind, text: "", warnings: [`File could not be read: ${detail}`] });
        }
      }
      controller.signal.throwIfAborted();
      if (!q && !extracted.some(file => file.text.trim())) {
        throw new Error("No readable content was found. Add a question or attach a readable file in your next message.");
      }
      setPhase("Preparing your answer…");
      const response = await fetch("/api/ask/stream", {
        method: "POST", headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ question: q, files: extracted, history }), signal: controller.signal,
      });
      if (!response.ok) {
        const data = await response.json().catch(() => null);
        throw new Error(errorMessage(data));
      }
      let completed = false;
      for await (const { event, data } of readEvents(response, controller.signal)) {
        controller.signal.throwIfAborted();
        if (activeRef.current !== active) return;
        if (event === "status") {
          const labels = { retrieving: "Finding relevant sources…", reranking: "Reviewing the context…", generating: "Preparing your answer…" };
          setPhase(labels[data.status] || "Working on your answer…");
        } else if (event === "token" && typeof data.text === "string") {
          active.buffer += data.text;
          if (!active.hasVisibleText) {
            active.hasVisibleText = true;
            flushTokens();
          } else if (!active.flushTimer) {
            // Batch only already-received tokens, never replay a completed answer.
            active.flushTimer = setTimeout(flushTokens, 50);
          }
        } else if (event === "done") {
          flushTokens();
          setMessages(current => current.map(message => message.id === assistantId
            ? { ...message, pending: false, sources: data.sources || [], elapsed: data.timings?.total_sec,
                notice: data.finish_reason === "length" ? "The response reached its length limit. You can ask me to continue." : "" }
            : message));
          completed = true;
          break;
        } else if (event === "error") {
          throw new Error(data.message || "The response was interrupted.");
        }
      }
      if (!completed) throw new Error("The connection ended before the response was complete.");
    } catch (error) {
      if (activeRef.current !== active) return;
      flushTokens();
      setMessages(current => current.map(message => message.id === assistantId
        ? { ...message, pending: false, error: true, notice: error.name === "AbortError" ? "Response stopped." : error.message || "Something went wrong." }
        : message));
    } finally {
      clearTimeout(active.flushTimer);
      if (activeRef.current === active) {
        activeRef.current = null;
        setLoading(false);
        setPhase("");
      }
    }
  }

  function keyDown(event) {
    if (event.key === "Enter" && !event.shiftKey && !event.nativeEvent.isComposing) {
      event.preventDefault();
      ask();
    }
  }

  return (
    <main className="relative min-h-screen">
      <header className="sticky top-0 z-30 border-b border-white/[.055] bg-[#07090c]/80 backdrop-blur-2xl">
        <div className="mx-auto flex h-[68px] max-w-[1360px] items-center justify-between gap-2 px-4 md:px-8">
          <Brand />
          <div className="flex items-center gap-3">
            <div className="hidden sm:block"><StatusPill /></div>
            <button onClick={newChat} className="flex items-center gap-1.5 rounded-lg border border-white/[.07] px-3 py-2 text-[11px] text-white/60 transition hover:bg-white/5 hover:text-white">
              <Plus size={12} /> New chat
            </button>
          </div>
        </div>
      </header>

      <div className="mx-auto flex min-h-[calc(100vh-68px)] max-w-[1360px]">
        <aside className="hidden w-[238px] shrink-0 border-r border-white/[.055] px-5 py-7 lg:block">
          <div className="sticky top-24">
            <div className="mb-3 px-2 text-[10px] font-semibold uppercase tracking-[.15em] text-white/35">Knowledge base</div>
            <div className="flex items-center gap-2.5 rounded-lg bg-white/[.055] px-3 py-2.5 text-[12px] text-white/80">
              <BookOpen size={14} /> Linux &amp; Infrastructure
            </div>
            <div className="mt-8 space-y-4 px-2 text-[11px] text-white/45">
              <div className="flex items-center gap-2"><ShieldCheck size={13} /> Private inference</div>
              <div className="flex items-center gap-2"><Paperclip size={13} /> File analysis</div>
              <p className="leading-5 text-white/35">Bring your questions and files. Get clear answers with supporting sources.</p>
            </div>
          </div>
        </aside>

        <section className="flex min-w-0 flex-1 justify-center" aria-label="Conversation">
          <div className="flex w-full max-w-[900px] flex-col px-4 pt-12 sm:px-7 md:pt-16" style={{ paddingBottom: composerHeight + 24 }}>
            {!messages.length && (
              <>
                <div className="mx-auto max-w-[690px] text-center">
                  <div className="mx-auto mb-5 grid h-12 w-12 place-items-center rounded-2xl border border-white/10 bg-gradient-to-b from-white/[.08] to-white/[.025]">
                    <Sparkles size={19} className="text-[#9fe870]" />
                  </div>
                  <h1 className="text-[31px] font-medium tracking-[-0.045em] text-white sm:text-[38px]">
                    Infrastructure knowledge,<span className="text-white/40"> on demand.</span>
                  </h1>
                  <p className="mx-auto mt-4 max-w-[590px] text-[14px] leading-6 text-white/45">
                    Your private production copilot, grounded in Linux runbooks. Ask, dictate, or attach your files.
                  </p>
                </div>
                <div className="mb-10 mt-10 grid grid-cols-1 gap-2 sm:grid-cols-2">
                  {suggestions.map(item => {
                    const Icon = item.icon;
                    return (
                      <button key={item.title} onClick={() => ask(item.prompt)} className="group glass flex items-start gap-3 rounded-xl p-4 text-left transition hover:border-white/[.14] hover:bg-white/[.055]">
                        <div className="mt-0.5 grid h-8 w-8 shrink-0 place-items-center rounded-lg border border-white/[.07] bg-white/[.04]"><Icon size={14} className="text-white/50" /></div>
                        <div className="min-w-0">
                          <div className="flex items-center gap-1.5 text-[13px] font-medium text-white/75">{item.title}<ChevronRight size={11} /></div>
                          <div className="mt-1 line-clamp-2 text-[12px] leading-[18px] text-white/40">{item.prompt}</div>
                        </div>
                      </button>
                    );
                  })}
                </div>
              </>
            )}

            <div className="space-y-8">
              {messages.map(message => (
                <article key={message.id} aria-label={message.role === "user" ? "Your message" : "Runbook AI response"}>
                  {message.role === "user" ? (
                    <div className="flex flex-col items-end gap-2">
                      {!!message.files?.length && (
                        <div className="flex max-w-full flex-wrap justify-end gap-2">
                          {message.files.map(file => <AttachmentCard key={file.id} file={file} />)}
                        </div>
                      )}
                      {message.content && <div className="max-w-[90%] whitespace-pre-wrap break-words rounded-2xl rounded-br-md border border-white/[.075] bg-white/[.055] px-4 py-3 text-[14px] leading-6 text-white/85">{message.content}</div>}
                    </div>
                  ) : (
                    <div>
                      <div className="mb-4 flex items-center gap-2.5">
                        <div className="grid h-7 w-7 place-items-center rounded-lg border border-[#9fe870]/15 bg-[#9fe870]/[.07]"><Sparkles size={12} className="text-[#9fe870]" /></div>
                        <span className="text-[12px] font-medium text-white/60">Runbook AI</span>
                      </div>
                      {message.pending && !message.content ? (
                        <div className="glass rounded-2xl p-5" role="status" aria-live="polite">
                          <div className="mb-4 flex items-center gap-2 text-[12px] text-white/55"><Loader2 size={13} className="animate-spin motion-reduce:animate-none" />{phase || "Preparing your answer…"}</div>
                          <div className="space-y-3 motion-safe:animate-pulse" aria-hidden="true">
                            <div className="h-2 w-[85%] rounded bg-white/[.06]" /><div className="h-2 w-[65%] rounded bg-white/[.04]" />
                          </div>
                        </div>
                      ) : (
                        <>
                          <MarkdownAnswer content={message.content} />
                          {message.notice && <p role="status" className="mt-3 text-[12px] leading-5 text-white/50">{message.notice}</p>}
                          <div className="mt-5 flex items-center justify-between border-t border-white/[.06] pt-3">
                            <span className="text-[10px] text-white/40">{Number.isFinite(message.elapsed) ? `Answered in ${Math.round(message.elapsed)}s` : ""}</span>
                            {message.content && <CopyButton text={message.content} />}
                          </div>
                          {!message.pending && !!message.sources?.length && (
                            <div className="mt-4">
                              <div className="mb-3 flex items-center gap-2 text-[11px] text-white/50"><BookOpen size={12} />Sources</div>
                              <div className="flex gap-2 overflow-x-auto pb-2">
                                {message.sources.filter((source, index, array) => array.findIndex(item => item.url === source.url) === index).slice(0, 4).map(source => <SourceCard key={source.url} source={source} />)}
                              </div>
                            </div>
                          )}
                        </>
                      )}
                    </div>
                  )}
                </article>
              ))}
              <div ref={bottomRef} style={{ scrollMarginBottom: composerHeight + 24 }} />
            </div>
          </div>
        </section>
      </div>

      {!nearBottom && !!messages.length && (
        <button onClick={() => { followBottomRef.current = true; bottomRef.current?.scrollIntoView({ behavior: "smooth", block: "end" }); }}
          style={{ bottom: composerHeight + 12 }} className="fixed right-5 z-50 flex items-center gap-2 rounded-full border border-white/15 bg-[#161b22] px-3 py-2 text-[11px] text-white/75 shadow-lg">
          <ArrowDown size={13} /> Latest message
        </button>
      )}

      <div ref={composerRef} className="pointer-events-none fixed inset-x-0 bottom-0 z-40 bg-gradient-to-t from-[#07090c] via-[#07090c]/95 to-transparent pb-4 pt-10">
        <div className="pointer-events-auto mx-auto max-w-[800px] px-4">
          {notice && <div role="alert" className="mb-2 rounded-xl border border-white/10 bg-[#11151c] px-3 py-2 text-[11px] leading-5 text-white/65">{notice}</div>}
          <div className={`glass rounded-[20px] p-2 shadow-[0_20px_80px_rgba(0,0,0,.5)] ${dragging ? "ring-2 ring-[#9fe870]/60" : ""}`}
            onDragEnter={event => { if (Array.from(event.dataTransfer.types).includes("Files")) { event.preventDefault(); dragDepthRef.current += 1; setDragging(true); } }}
            onDragOver={event => { if (Array.from(event.dataTransfer.types).includes("Files")) event.preventDefault(); }}
            onDragLeave={event => { event.preventDefault(); dragDepthRef.current = Math.max(0, dragDepthRef.current - 1); if (!dragDepthRef.current) setDragging(false); }}
            onDrop={event => { event.preventDefault(); dragDepthRef.current = 0; setDragging(false); addFiles(event.dataTransfer.files); }}>
            {!!attachments.length && <div className="flex max-h-48 flex-wrap gap-2 overflow-y-auto px-2 pt-2">{attachments.map(file => <AttachmentCard key={file.id} file={file} onRemove={removeFile} />)}</div>}
            <textarea ref={textareaRef} value={question} maxLength={4000} aria-label="Message" rows={1}
              onChange={event => { if (recognitionRef.current) stopVoice(); setQuestion(event.target.value); }}
              onKeyDown={keyDown}
              onPaste={event => { if (event.clipboardData.files.length) { event.preventDefault(); addFiles(event.clipboardData.files); } }}
              placeholder={dragging ? "Drop your files here" : listening ? "Listening… You can edit before sending." : "Ask a question or attach your files…"}
              className="max-h-[180px] min-h-[52px] w-full resize-none bg-transparent px-3.5 py-3 text-[14px] leading-6 text-white/90 outline-none placeholder:text-white/35" />
            <div className="flex items-center justify-between px-2 pb-1">
              <div className="flex items-center gap-1">
                <input ref={inputRef} type="file" multiple accept={FILE_ACCEPT} onChange={event => { addFiles(event.target.files); event.target.value = ""; }} className="hidden" aria-label="Attach files" />
                <button type="button" onClick={() => inputRef.current?.click()} disabled={attachments.length >= MAX_FILES}
                  aria-label="Attach files" title="Attach up to 5 files, 10 MB each" className="grid h-8 w-8 place-items-center rounded-lg text-white/50 transition hover:bg-white/5 hover:text-white disabled:opacity-25"><Paperclip size={15} /></button>
                <button type="button" onClick={toggleVoice} aria-label={listening ? "Stop dictation" : "Start dictation"} aria-pressed={listening}
                  title="Voice dictation" className={`grid h-8 w-8 place-items-center rounded-lg transition ${listening ? "bg-red-400/10 text-red-300" : "text-white/50 hover:bg-white/5 hover:text-white"}`}><Mic size={15} /></button>
                <span className="ml-2 hidden text-[10px] text-white/30 sm:inline">Shift + Enter for a new line</span>
              </div>
              {loading ? (
                <button type="button" onClick={stopGeneration} aria-label="Stop response" className="grid h-8 w-8 place-items-center rounded-xl bg-white text-black"><Square size={11} fill="currentColor" /></button>
              ) : (
                <button type="button" onClick={() => ask()} disabled={!question.trim() && !attachments.length} aria-label="Send message"
                  className="grid h-8 w-8 place-items-center rounded-xl bg-[#9fe870] text-[#0b1407] transition hover:brightness-110 disabled:cursor-not-allowed disabled:opacity-25"><ArrowUp size={15} /></button>
              )}
            </div>
          </div>
          <p className="mt-2 text-center text-[10px] text-white/30">Up to 5 files · 10 MB per file · You control what you share</p>
        </div>
      </div>
    </main>
  );
}

"use client";

import { Children, isValidElement } from "react";
import CopyButton from "./copy-button";

// ReactMarkdown invokes this only for <pre>, so inline <code> is unaffected.
export default function CodeBlock({ children }) {
  const code = Children.toArray(children).find(isValidElement);
  const content = code?.props.children ?? "";
  const text = typeof content === "string" ? content : Children.toArray(content).join("");
  const language = /(?:^|\s)language-([^\s]+)/.exec(code?.props.className || "")?.[1];
  return (
    <div className="code-block">
      <div className="flex items-center justify-between gap-3 border-b border-white/[.07] px-3 py-1.5">
        <span className="font-mono text-[10px] text-white/40">{language || "Code"}</span>
        <CopyButton text={text} label="Copy code" />
      </div>
      <pre><code className={code?.props.className}>{text}</code></pre>
    </div>
  );
}

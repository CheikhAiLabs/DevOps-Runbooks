"use client";

import { memo } from "react";
import ReactMarkdown from "react-markdown";
import remarkGfm from "remark-gfm";
import CodeBlock from "./code-block";

const components = { pre: CodeBlock };
const plugins = [remarkGfm];

const MarkdownAnswer = memo(function MarkdownAnswer({ content }) {
  return <div className="answer-markdown"><ReactMarkdown remarkPlugins={plugins} components={components}>{content}</ReactMarkdown></div>;
});
export default MarkdownAnswer;

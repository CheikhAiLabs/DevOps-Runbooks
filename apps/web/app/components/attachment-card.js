import { FileCode2, FileText, FileSpreadsheet, Image as ImageIcon, Loader2, X } from "lucide-react";
import { formatSize } from "../../lib/files";

export default function AttachmentCard({ file, onRemove }) {
  const Icon = file.kind === "image" ? ImageIcon
    : file.kind === "code" ? FileCode2
    : file.kind === "spreadsheet" ? FileSpreadsheet : FileText;
  const note = file.error || file.warnings?.join(" ") || "";
  return (
    <div className={`flex w-[210px] max-w-full items-center gap-2.5 rounded-xl border p-2 ${file.error ? "border-red-300/20 bg-red-300/5" : "border-white/10 bg-white/[.035]"}`}>
      {file.preview ? (
        <img src={file.preview} alt={file.name} className="h-10 w-10 shrink-0 rounded-lg object-cover" />
      ) : (
        <div className="grid h-10 w-10 shrink-0 place-items-center rounded-lg bg-white/5 text-white/50">
          <Icon size={18} aria-hidden="true" />
        </div>
      )}
      <div className="min-w-0 flex-1">
        <p className="truncate text-[11px] font-medium text-white/80" title={file.name}>{file.name}</p>
        <div className="mt-0.5 flex items-center gap-1 text-[10px] text-white/40">
          {file.status === "reading" && <Loader2 size={10} className="animate-spin" aria-hidden="true" />}
          {formatSize(file.size)}
          {file.status === "reading" && " · Reading…"}
          {file.status === "queued" && " · Waiting"}
        </div>
        {note && <p title={note} className={`mt-1 text-[10px] leading-4 ${file.error ? "text-red-200/90" : "text-amber-100/70"}`}>{note}</p>}
      </div>
      {onRemove && (
        <button type="button" onClick={() => onRemove(file.id)} aria-label={`Remove ${file.name}`}
          className="grid h-7 w-7 shrink-0 place-items-center rounded-lg text-white/40 hover:bg-white/10 hover:text-white focus-visible:outline-2 focus-visible:outline-[#9fe870]">
          <X size={12} />
        </button>
      )}
    </div>
  );
}

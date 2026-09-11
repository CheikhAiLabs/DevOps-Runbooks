// Keep supported extensions and limits aligned with apps/api/file_extraction.py.
export const MAX_FILE_BYTES = 10 * 1024 * 1024;
export const MAX_FILES = 5;
export const MAX_EXTRACTED_CHARS = 12000;
export const MAX_FILE_CONTEXT_CHARS = 20000;

const groups = {
  image: ["png", "jpg", "jpeg", "webp"],
  pdf: ["pdf"],
  document: ["docx"],
  spreadsheet: ["csv", "xlsx"],
  text: ["txt", "md", "markdown", "json", "yaml", "yml", "xml", "log"],
  code: ["py", "js", "ts", "jsx", "tsx", "sh", "bash", "hcl", "tf", "tfvars", "ini", "conf", "toml", "sql", "go", "java", "c", "cpp", "h", "rs"],
};

export const FILE_KINDS = Object.fromEntries(
  Object.entries(groups).flatMap(([kind, extensions]) => extensions.map(ext => [ext, kind]))
);
export const FILE_ACCEPT = Object.keys(FILE_KINDS).map(ext => `.${ext}`).join(",");

export function fileKind(name) {
  return FILE_KINDS[name.split(".").pop().toLowerCase()];
}

export function validateFile(file) {
  if (!fileKind(file.name)) return "This file type is not supported.";
  if (file.name.length > 200) return "The filename must be 200 characters or fewer.";
  if (!file.size) return "The file is empty.";
  if (file.size > MAX_FILE_BYTES) return "Files must be 10 MB or smaller.";
  return null;
}

export function formatSize(bytes) {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${Math.ceil(bytes / 1024)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}

export function errorMessage(data, fallback = "The request could not be completed.") {
  if (typeof data?.detail === "string") return data.detail;
  if (typeof data?.error === "string") return data.error;
  if (Array.isArray(data?.detail)) return "Some message content exceeds the allowed limits.";
  return fallback;
}

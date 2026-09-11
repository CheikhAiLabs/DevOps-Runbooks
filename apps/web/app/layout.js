import "./globals.css";

export const metadata = {
  title: "Runbook AI",
  description: "Private Linux and infrastructure copilot",
};

export default function RootLayout({ children }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}

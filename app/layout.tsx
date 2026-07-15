import type { Metadata } from "next";
import { headers } from "next/headers";
import "./globals.css";

export async function generateMetadata(): Promise<Metadata> {
  const requestHeaders = await headers();
  const host = requestHeaders.get("host") || "localhost:3000";
  const protocol = requestHeaders.get("x-forwarded-proto") || (host.startsWith("localhost") ? "http" : "https");
  const base = `${protocol}://${host}`;
  const description = "围绕地点与在场感的异地心愿轻互助平台。";
  return {
    title: "哈喽卧得｜让想说的话抵达远方",
    description,
    icons: { icon: "/favicon.svg", shortcut: "/favicon.svg" },
    openGraph: {
      title: "哈喽卧得｜让想说的话抵达远方",
      description,
      images: [{ url: `${base}/og.png`, width: 1536, height: 1024, alt: "哈喽卧得品牌分享卡" }],
    },
    twitter: { card: "summary_large_image", title: "哈喽卧得", description, images: [`${base}/og.png`] },
  };
}

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="zh-CN">
      <body>{children}</body>
    </html>
  );
}

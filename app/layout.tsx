import type { Metadata } from "next";
import "./globals.css";

const publicSite = "https://hanselzzh-wow.github.io";
const description = "围绕地点与在场感的异地心愿轻互助平台。";

export const metadata: Metadata = {
  metadataBase: new URL(publicSite),
  title: "哈喽卧得｜让想说的话抵达远方",
  description,
  icons: { icon: "/favicon.svg", shortcut: "/favicon.svg" },
  openGraph: {
    title: "哈喽卧得｜让想说的话抵达远方",
    description,
    images: [{ url: "/og.png", width: 1536, height: 1024, alt: "哈喽卧得品牌分享卡" }],
  },
  twitter: { card: "summary_large_image", title: "哈喽卧得", description, images: ["/og.png"] },
};

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

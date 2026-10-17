import type { Metadata, Viewport } from "next";
import { Archivo, Archivo_Narrow, Instrument_Serif, JetBrains_Mono } from "next/font/google";
import { site } from "@/config/site";
import "./globals.css";

const ui = Archivo({ subsets: ["latin"], weight: ["400", "500", "600", "700"], variable: "--font-ui" });
const credit = Archivo_Narrow({ subsets: ["latin"], weight: ["400", "600", "700"], variable: "--font-credit" });
const serif = Instrument_Serif({ subsets: ["latin"], weight: "400", style: ["normal", "italic"], variable: "--font-serif" });
const mono = JetBrains_Mono({ subsets: ["latin"], weight: ["400", "500"], variable: "--font-mono" });

export const metadata: Metadata = {
  metadataBase: new URL(site.url),
  title: site.title,
  description: site.description,
  applicationName: site.name,
  keywords: ["end credits", "credit roll", "film credits", "end credits maker", "ProRes", "filmmaking"],
  alternates: { canonical: "/" },
  openGraph: {
    type: "website",
    url: "/",
    siteName: site.name,
    title: site.title,
    description: site.description,
    locale: "en",
  },
  twitter: { card: "summary_large_image", title: site.title, description: site.description },
};

export const viewport: Viewport = {
  themeColor: "#000000",
  colorScheme: "light",
};

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html lang="en" className={`${ui.variable} ${credit.variable} ${serif.variable} ${mono.variable}`}>
      <body>
        <a className="skip-link" href="#top">
          Skip to content
        </a>
        {children}
      </body>
    </html>
  );
}

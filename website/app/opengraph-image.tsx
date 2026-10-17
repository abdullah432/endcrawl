import { readFile } from "node:fs/promises";
import { join } from "node:path";
import { ImageResponse } from "next/og";
import { site } from "@/config/site";
import { hero } from "@/content/landing";

// Rendered once at build time: the site is a static export.
export const dynamic = "force-static";

export const alt = `${site.name} — ${hero.heading.text} ${hero.heading.emphasis}`;
export const size = { width: 1200, height: 630 };
export const contentType = "image/png";

const font = (file: string) => readFile(join(process.cwd(), "assets/fonts", file));
const [serif, serifItalic, narrow] = await Promise.all([
  font("InstrumentSerif-Regular.ttf"),
  font("InstrumentSerif-Italic.ttf"),
  font("ArchivoNarrow-Bold.ttf"),
]);

/** The social preview: the hero, as a still — black, the headline, a few credits. */
export default function Image() {
  const credit = { fontFamily: "Archivo Narrow", textTransform: "uppercase" as const };
  return new ImageResponse(
    (
      <div
        style={{
          width: "100%",
          height: "100%",
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          justifyContent: "center",
          background: "radial-gradient(60% 60% at 50% 0%, rgba(12,140,233,.35), #000 70%)",
          color: "#fff",
          gap: 28,
        }}
      >
        <div style={{ ...credit, fontSize: 22, letterSpacing: 8, fontWeight: 700 }}>Lastreel</div>
        <div style={{ display: "flex", fontFamily: "Instrument Serif", fontSize: 150, lineHeight: 1 }}>
          {hero.heading.text}&nbsp;<span style={{ fontStyle: "italic" }}>{hero.heading.emphasis}</span>
        </div>
        <div style={{ fontFamily: "Instrument Serif", fontSize: 34, color: "rgba(255,255,255,.78)", maxWidth: 860, textAlign: "center" }}>
          {site.description}
        </div>
        <div style={{ ...credit, fontSize: 20, letterSpacing: 4, marginTop: 18, color: "rgba(255,255,255,.6)" }}>
          {hero.footnote}
        </div>
      </div>
    ),
    {
      ...size,
      fonts: [
        { name: "Instrument Serif", data: serif, style: "normal", weight: 400 },
        { name: "Instrument Serif", data: serifItalic, style: "italic", weight: 400 },
        { name: "Archivo Narrow", data: narrow, style: "normal", weight: 700 },
      ],
    },
  );
}

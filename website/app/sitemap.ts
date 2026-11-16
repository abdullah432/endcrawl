import type { MetadataRoute } from "next";
import { site } from "@/config/site";

// Rendered once at build time: the site is a static export.
export const dynamic = "force-static";

export default function sitemap(): MetadataRoute.Sitemap {
  return [
    { url: site.url, changeFrequency: "monthly", priority: 1 },
    ...["terms", "privacy", "refunds", "contact"].map(path => ({
      url: new URL(`/${path}`, site.url).toString(),
      changeFrequency: "monthly" as const,
      priority: 0.4,
    })),
  ];
}

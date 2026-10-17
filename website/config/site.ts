/**
 * Site-wide configuration: where the page lives and every address it links
 * out to. Deployment-specific values come from the environment so preview
 * and production builds point at the right places.
 */

/** Canonical origin, used for metadata, the sitemap and social previews. */
const siteUrl =
  process.env.NEXT_PUBLIC_SITE_URL ??
  (process.env.VERCEL_PROJECT_PRODUCTION_URL
    ? `https://${process.env.VERCEL_PROJECT_PRODUCTION_URL}`
    : "http://localhost:3000");

export const site = {
  name: "LastReel",
  title: "LastReel — End credits for people who make films",
  description:
    "Build your end credits on your phone. Time them to the frame. Export a master your editor won’t send back.",
  url: siteUrl,
  year: 2026,
} as const;

export const links = {
  /** Verified listing: “Last Reel: End Credits Maker” on Google Play. */
  googlePlay: "https://play.google.com/store/apps/details?id=com.lastreel.app",
  /** The Flutter web app — Pro workspace; anyone can sign in and preview. */
  webApp: process.env.NEXT_PUBLIC_WEB_APP_URL ?? "https://endcrawl-620c2.web.app",
  privacy: "https://cookoo.dev/lastreel/privacy-policy",
  /** No public terms page yet; the footer leaves the link out until one exists. */
  terms: process.env.NEXT_PUBLIC_TERMS_URL ?? null,
  help: "https://cookoo.dev/lastreel/help",
  contact: "mailto:hello@cookoo.dev",
} as const;

/** In-page anchors shared by the header, footer and calls to action. */
export const anchors = {
  top: "top",
  get: "get",
  how: "how",
  plans: "plans",
  faq: "faq",
} as const;

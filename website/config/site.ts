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

/** Enable only after live Paddle checkout has passed end-to-end verification. */
export const webBillingAvailable = process.env.NEXT_PUBLIC_WEB_BILLING_ENABLED === "true";
const webAppUrl = process.env.NEXT_PUBLIC_WEB_APP_URL ?? "https://app.lastreel.cookoo.dev/";
const subscribeUrl = new URL(webAppUrl);
subscribeUrl.searchParams.set("subscribe", "1");

export const site = {
  name: "LastReel",
  title: "LastReel — End credits for people who make films",
  description:
    "Build your end credits on your phone. Time them to the frame. Export a master your editor won’t send back.",
  url: siteUrl,
  year: 2026,
  clarityProjectId: process.env.NEXT_PUBLIC_CLARITY_PROJECT_ID ?? "z6hm6z53lz",
} as const;

export const links = {
  /** Verified listing: “Last Reel: End Credits Maker” on Google Play. */
  googlePlay: "https://play.google.com/store/apps/details?id=com.lastreel.app",
  appStore: "https://apps.apple.com/app/last-reel-end-credits-maker/id6822275411",
  /** The Flutter web app — normal Free and Pro plans on the same account. */
  webApp: webAppUrl,
  subscribe: subscribeUrl.toString(),
  privacy: "/privacy",
  terms: "/terms",
  refunds: "/refunds",
  help: "https://cookoo.dev/lastreel/help",
  contact: "/contact",
} as const;

/** In-page anchors shared by the header, footer and calls to action. */
export const anchors = {
  top: "top",
  get: "get",
  how: "how",
  plans: "plans",
  faq: "faq",
} as const;

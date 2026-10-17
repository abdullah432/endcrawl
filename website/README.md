# LastReel website

The marketing landing page for LastReel, built with Next.js (App Router) and TypeScript.

```bash
npm install
npm run dev        # http://localhost:3000
npm run lint
npm run typecheck
npm run build && npm run start
```

## Structure

- `app/` — routing only: the page, layout and metadata, social image, robots and sitemap.
- `features/landing/` — the page's sections (hero, problem, how it works, made for, plans, FAQ, closing, footer).
- `components/ui/` — reusable pieces: container, eyebrow, display heading, button link, store buttons, wordmark.
- `content/landing.ts` — every word on the page; sections render from it.
- `config/site.ts` — site URL and every outbound link.
- `assets/fonts/` — static TTFs for the generated social image (Open Font License).

Everything is a Server Component except the hero roll's pause button (`RollControl`).
The FAQ uses native `<details>`, so it works without JavaScript.

## Configuration

| Variable | Purpose | Default |
| --- | --- | --- |
| `NEXT_PUBLIC_SITE_URL` | Canonical origin for metadata, sitemap and social previews | Vercel production URL, else `http://localhost:3000` |
| `NEXT_PUBLIC_WEB_APP_URL` | “Log in” and “Open the web app” | `https://endcrawl-620c2.web.app` |
| `NEXT_PUBLIC_TERMS_URL` | Footer “Terms” link; hidden until set | — |

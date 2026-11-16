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
| Public policies | `/terms`, `/privacy`, `/refunds`, `/contact`  | — |

`NEXT_PUBLIC_WEB_BILLING_ENABLED=true` changes the Pro call to action to the
Flutter app's `?subscribe=1` entry and updates billing copy for Paddle. Leave it
unset during sandbox development; enable only after live checkout verification.
The Flutter app and Functions have their own billing gates. The website never
handles credentials, account identity, payment details, or entitlement grants.

## Public policy content

Routes delegate to `features/legal/PolicyPage.tsx` and `content/legal/*.json`.
The layout reuses the existing design tokens, fonts, wordmark and footer. These
are static Server Components with no client state. Flutter keeps its existing
Riverpod link service and settings feature structure. Run
`python3 scripts/sync-legal-documents.py` from the repository root after changing
Terms or Refund content to refresh the offline Flutter documents.

The owner confirmed the operator as COOKOO Technologies (SMC) Private limited
and selected Paddle's refund policy without an extra LastReel guarantee. Existing
support and catalog prices are retained. Do not add an unconfirmed registration
country or governing-law clause. Keep website catalog prices aligned with Paddle.
Deploy website before app when changing public routes. Live checkout remains
off until the separate verification and production activation work is complete.

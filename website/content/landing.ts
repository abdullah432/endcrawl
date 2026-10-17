/**
 * Every word on the landing page, approved copy from the LastReel website
 * design. Sections render from this data, so copy changes happen here.
 */
import { anchors, links } from "@/config/site";

/** Display headings are set in the serif with an italic second half. */
export type Heading = { text: string; emphasis?: string; after?: string };

export type CreditLine =
  | { kind: "head"; text: string }
  | { kind: "name"; text: string }
  | { kind: "pair"; role: string; name: string }
  | { kind: "gap" };

export type Pair = { role: string; name: string };

export const nav = [
  { label: "How it works", href: `#${anchors.how}` },
  { label: "Plans", href: `#${anchors.plans}` },
  { label: "FAQ", href: `#${anchors.faq}` },
] as const;

export const footerNav = [
  ...nav,
  { label: "Privacy", href: links.privacy },
  ...(links.terms ? [{ label: "Terms", href: links.terms }] : []),
  { label: "Contact", href: links.contact },
];

export const hero = {
  eyebrow: "End credits · for people who make films",
  heading: { text: "Credit", emphasis: "everyone." } satisfies Heading,
  lede: "Build your end credits on your phone. Time them to the frame. Export a master your editor won’t send back.",
  footnote: "Free to start · No watermark · Finish at a desk with Pro",
  rollStatus: "24 fps · 4 px/frame · no judder",
  rollStamp: "Made in LastReel · 00:02:41:00",
};

const c = {
  head: (text: string): CreditLine => ({ kind: "head", text }),
  name: (text: string): CreditLine => ({ kind: "name", text }),
  pair: (role: string, name: string): CreditLine => ({ kind: "pair", role, name }),
  gap: { kind: "gap" } as CreditLine,
};

/** The sample roll behind the hero — a short film's credits. */
export const heroCredits: CreditLine[] = [
  c.head("Directed by"), c.name("Maya Okonkwo"), c.gap,
  c.head("Cast"),
  c.pair("Renny", "Sofia Alvarez"), c.pair("Marcus", "Idris Oyelaran"), c.pair("Dr. Vance", "Helen Tsai"),
  c.pair("Bartender", "Nkechi Obi"), c.pair("Ferry captain", "Teodor Lindqvist"), c.pair("and", "Cleo Barr"), c.gap,
  c.head("Director of photography"), c.name("Yusuf Karadeniz"), c.gap,
  c.head("Editor"), c.name("Bruno Takahashi"), c.gap,
  c.head("Original music"), c.name("Hana Bexley"), c.gap,
  c.head("Crew"),
  c.pair("Gaffer", "Tomás Iriarte"), c.pair("Key grip", "Kwabena Mensah"),
  c.pair("Sound mixer", "Rosalind Achterberg"), c.pair("Colorist", "Oskar Brandt"), c.gap,
  c.head("Special thanks"), c.name("The people of Port Ellis"), c.gap,
];

export const problem = {
  eyebrow: "The last two minutes of your film",
  heading: { text: "Credits are the last thing in the cut,", emphasis: "and the first thing to break." } satisfies Heading,
  body: "You’ve locked picture. Now it’s two hundred names in a title tool, a scroll that stutters on the big screen, and a typo someone spots the night before the festival deadline. LastReel takes the fiddly, exacting part off your plate.",
  cardHead: "Also starring",
  cardFoot: "Handled by LastReel",
  pains: [
    { role: "Cast list", name: "Arrives as a screenshot" },
    { role: "Spelling", name: "Wrong. Twice." },
    { role: "Scroll speed", name: "Stutters on the projector" },
    { role: "Last-minute add", name: "The caterer" },
    { role: "Delivery spec", name: "ProRes, by Friday" },
    { role: "Title tool", name: "Two hundred text boxes" },
  ] satisfies Pair[],
};

export type StepVisual = "paste" | "runtime" | "blocks" | "fix" | "codecs" | "desk";

export const howItWorks = {
  heading: { text: "Make them", emphasis: "properly." } satisfies Heading,
  intro: "Not a text animator. LastReel thinks in runtimes, frame rates and whole pixels, the way a delivery spec arrives.",
  steps: [
    {
      visual: "paste",
      title: "Paste the call sheet.",
      body: "Copy the cast list from wherever it lives. LastReel splits roles from names with rules you can see, and flags anything it can’t split instead of guessing.",
      alt: "A pasted cast list split into role and name columns, with one line flagged for a look.",
    },
    {
      visual: "runtime",
      title: "Hit the runtime.",
      body: "Type the length the spec asks for. LastReel works out the scroll speed, warns if it would stutter or rush a name off screen, and offers the nearest clean runtimes.",
      alt: "A runtime of 2 minutes 41 seconds giving 4 pixels per frame, marked no judder and readable.",
    },
    {
      visual: "blocks",
      title: "Every block, built in.",
      body: "Title cards, two-column cast, departments, music cues, logo rows, dedications, legal lines. 27 block types, laid out the way real credits are.",
      alt: "Block types: title card, cast, department, crew, music cue, logo row, special thanks, dedication, copyright and hold card.",
    },
    {
      visual: "fix",
      title: "Fix it. Render again.",
      body: "A misspelled name is a thirty-second fix, not a favour you owe a motion designer. Change it on your phone and export a new version in minutes.",
      alt: "An editor credit with a misspelled name struck through, the corrected name below, rendered again.",
    },
    {
      visual: "codecs",
      title: "Deliver the master.",
      body: "H.264 and HEVC up to 1080p, free and unwatermarked. ProRes, PNG with alpha and 4K when the festival, the colourist or the distributor asks for them.",
      alt: "Export formats: H.264 and HEVC free; ProRes 422 HQ, ProRes 4444 with alpha and PNG sequence with alpha on Pro.",
    },
    {
      visual: "desk",
      title: "Finish at a desk.",
      body: "Start on the bus, finish in the edit suite. With Pro, the same projects open in the web app: blocks, monitor and a true-length timeline side by side.",
      alt: "The desktop web app with blocks, monitor and settings side by side over a timeline.",
    },
  ] satisfies { visual: StepVisual; title: string; body: string; alt: string }[],
  parsed: [
    { role: "Renny", name: "Sofia Alvarez" },
    { role: "Marcus", name: "Idris Oyelaran" },
    { role: "Dr. Vance", name: "Helen Tsai" },
    { role: "Bartender", name: "Nkechi Obi" },
  ] satisfies Pair[],
  rawLines: ["Renny — Sofia Alvarez", "Marcus — Idris Oyelaran", "Dr. Vance — Helen Tsai", "Bartender — Nkechi Obi"],
  flaggedLine: "Young Renny Cleo Barr",
  blockChips: [
    ["TTL", "Title card"], ["CST", "Cast"], ["DPT", "Department"], ["CRW", "Crew"], ["SNG", "Music cue"],
    ["LGO", "Logo row"], ["THX", "Special thanks"], ["DED", "Dedication"], ["CPY", "Copyright"], ["HLD", "Hold card"],
  ] as const,
  codecs: [
    { name: "H.264", plan: "free" },
    { name: "HEVC", plan: "free" },
    { name: "ProRes 422 HQ", plan: "pro" },
    { name: "ProRes 4444 · alpha", plan: "pro" },
    { name: "PNG sequence · alpha", plan: "pro" },
  ] as const,
};

export const madeFor = {
  eyebrow: "Made for",
  items: ["Short films", "Features", "Student films", "Festival cuts", "Documentaries", "Music videos", "Vertical cuts"],
  body: "Templates for features, shorts and vertical cuts set the canvas, frame rate and block order, so you start from something that already looks right.",
};

export const plans = {
  heading: { text: "Start free.", emphasis: "Go Pro for delivery." } satisfies Heading,
  intro: "Editing is identical on both plans. Pro adds projects, master formats and the desk. Google Play shows the current price and any offer before you subscribe.",
  free: {
    label: "Free",
    title: "Make your credits.",
    items: [
      "Every block, timing and look tool",
      "Two projects, kept as long as you like",
      "H.264 and HEVC up to 1080p",
      "No watermark, ever",
      "One Pro render per rewarded ad",
    ],
    cta: "Get the app",
  },
  pro: {
    label: "Pro",
    title: "Deliver them anywhere.",
    items: [
      "Unlimited projects",
      "ProRes, PNG alpha and 4K on every render",
      "No ads",
      "LastReel on the web, at your desk",
      "The same projects on every device",
    ],
    cta: "Subscribe in the app",
  },
};

export const faq = {
  heading: { text: "Fair", emphasis: "questions." } satisfies Heading,
  items: [
    {
      q: "Why are end credits so hard to get right?",
      a: "Because they’re long, exact and late. Hundreds of names arrive from different people in different formats, and the roll has to move at a speed that doesn’t stutter and still leaves time to read each name. LastReel does the maths and the layout so you can concentrate on getting every name right.",
    },
    { q: "Is there a watermark on free exports?", a: "No. Free exports in H.264 and HEVC up to 1080p are clean." },
    {
      q: "Which formats can I deliver?",
      a: "H.264 and HEVC on every plan. ProRes 422 HQ, ProRes 4444, PNG sequences with alpha and 4K come with Pro. On the free plan you can unlock one Pro render by watching an ad.",
    },
    {
      q: "Can I work on my computer?",
      a: "Yes, with Pro. Log in to the web app with the same account and your projects are already there. Anyone can log in and preview; editing and export need Pro.",
    },
    {
      q: "Is LastReel on iPhone or iPad?",
      a: "Not yet; it’s coming soon. Today LastReel runs on Android phones and tablets, and on the web with Pro.",
    },
    {
      q: "How do I subscribe, and what does it cost?",
      a: "Subscribe in the Android app through Google Play. Google Play shows the current price and any offer before you confirm, and handles billing and cancellation.",
    },
    { q: "What happens if Pro ends?", a: "Nothing is deleted. You keep every project, two stay editable, and ads return on the free plan." },
  ],
};

export const closing = {
  eyebrow: "No crew members were harmed in the making of these credits",
  heading: { text: "Roll", emphasis: "your", after: "credits." } satisfies Heading,
  webApp: "Open the web app",
  signoff: "Now go make the next one",
};

export const footer = {
  tagline: "End credits for people who make films.",
  trademark: "Google Play is a trademark of Google LLC.",
};

export const header = { logIn: "Log in", getStarted: "Get started" };

export const stores = {
  googlePlay: { kicker: "Get it on", name: "Google Play" },
  ios: { name: "iPhone & iPad", status: "Coming soon" },
};

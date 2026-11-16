import type { Metadata } from "next";
import { PolicyPage } from "@/features/legal/PolicyPage";
import styles from "@/features/legal/PolicyPage.module.css";
export const metadata: Metadata = { title: "Contact — LastReel", alternates: { canonical: "/contact" } };
const document = { title: "Let’s sort it out.", updated: "3 November 2026", summary: "Help with your credits, your account or your subscription.", sections: [
  { heading: "LastReel support", body: "Email hello@cookoo.dev for product questions, technical issues, account access or privacy requests. Include your device, browser or app version and a description of the problem. Do not send passwords or full payment-card details." },
  { heading: "Paddle web billing", body: "For receipts, web charges, cancellation and refund requests, use Paddle buyer support at paddle.net or the support link in your receipt. In LastReel, Settings → Manage billing opens the provider responsible for your subscription." },
  { heading: "App Store or Google Play", body: "For purchases made through Apple or Google, use that store’s subscription settings or refund process. LastReel support can help investigate missing Pro access; sign in to the same LastReel account used for the purchase." },
  { heading: "The people behind LastReel", body: "LastReel is a COOKOO TECHNOLOGIES (SMC-PRIVATE) LIMITED product. Find our studio at cookoo.dev." },
] };
export default function Page() { return <PolicyPage document={document}><nav className={styles.resources} aria-label="Contact options"><a href="mailto:hello@cookoo.dev?subject=LastReel%20support">Email LastReel support ↗</a><a href="https://paddle.net">Paddle buyer support ↗</a></nav></PolicyPage>; }

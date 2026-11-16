import type { Metadata } from "next";
import document from "@/content/legal/terms.json";
import { PolicyPage } from "@/features/legal/PolicyPage";
import styles from "@/features/legal/PolicyPage.module.css";
export const metadata: Metadata = { title: `${document.title} — LastReel`, alternates: { canonical: "/terms" } };
export default function Page() { return <PolicyPage document={document}><nav className={styles.resources} aria-label="Related policies"><a href="https://www.paddle.com/legal/buyer-terms">Paddle Buyer Terms</a><a href="/refunds">Refund & cancellation</a></nav></PolicyPage>; }

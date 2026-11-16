import type { Metadata } from "next";
import document from "@/content/legal/refunds.json";
import { PolicyPage } from "@/features/legal/PolicyPage";
import styles from "@/features/legal/PolicyPage.module.css";
export const metadata: Metadata = { title: `${document.title} — LastReel`, alternates: { canonical: "/refunds" } };
export default function Page() { return <PolicyPage document={document}><nav className={styles.resources} aria-label="Related policies"><a href="https://www.paddle.com/legal/refund-policy">Paddle Refund Policy</a><a href="https://paddle.net">Paddle buyer support</a><a href="https://reportaproblem.apple.com/">Apple refund requests</a><a href="https://support.google.com/googleplay/answer/2479637">Google Play help</a></nav></PolicyPage>; }

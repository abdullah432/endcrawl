import type { Metadata } from "next";
import document from "@/content/legal/privacy.json";
import { PolicyPage } from "@/features/legal/PolicyPage";
import styles from "@/features/legal/PolicyPage.module.css";
export const metadata: Metadata = { title: `${document.title} — LastReel`, alternates: { canonical: "/privacy" } };
export default function Page() { return <PolicyPage document={document}><nav className={styles.resources} aria-label="Related policies"><a href="https://firebase.google.com/support/privacy">Firebase privacy</a><a href="https://www.revenuecat.com/privacy/">RevenueCat privacy</a><a href="https://www.paddle.com/legal/privacy">Paddle privacy</a><a href="https://privacy.microsoft.com/privacystatement">Microsoft privacy</a><a href="https://policies.google.com/privacy">Google privacy</a></nav></PolicyPage>; }

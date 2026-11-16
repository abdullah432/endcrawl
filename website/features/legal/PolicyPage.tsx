import Link from "next/link";
import { Container } from "@/components/ui/Container";
import { Wordmark } from "@/components/ui/Wordmark";
import { SiteFooter } from "@/features/landing/SiteFooter";
import { links } from "@/config/site";
import styles from "./PolicyPage.module.css";

export type PolicyDocument = {
  title: string;
  summary: string;
  updated: string;
  sections: { heading: string; body: string }[];
};

export const policyLinks = [
  { label: "Terms", href: "/terms" },
  { label: "Privacy", href: "/privacy" },
  { label: "Refund & cancellation", href: "/refunds" },
  { label: "Contact", href: "/contact" },
];

/** Static documents need no client state; account actions remain in Flutter. */
export function PolicyPage({ document, children }: { document: PolicyDocument; children?: React.ReactNode }) {
  return <>
    <Container as="header" className={styles.header}>
      <Wordmark href="/" />
      <a href={links.webApp}>Open the web app ↗</a>
    </Container>
    <Container as="main" id="top" className={styles.main}>
      <aside className={styles.sidebar}>
        <p className={styles.eyebrow}>THE DETAILS</p>
        <nav aria-label="Policies">{policyLinks.map(link => <a key={link.href} href={link.href}>{link.label}</a>)}</nav>
        <Link href="/#plans">Compare Free & Pro ↗</Link>
      </aside>
      <article className={styles.article}>
        <p className={styles.eyebrow}>LAST UPDATED · {document.updated}</p>
        <h1>{document.title}</h1>
        <p className={styles.summary}>{document.summary}</p>
        {document.sections.map((section, index) => <section className={styles.section} key={section.heading}>
          <h2>{index + 1}. {section.heading}</h2><p>{section.body}</p>
        </section>)}
        {children}
      </article>
    </Container>
    <SiteFooter />
  </>;
}

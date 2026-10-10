import { ButtonLink } from "@/components/ui/ButtonLink";
import { Container } from "@/components/ui/Container";
import { Wordmark } from "@/components/ui/Wordmark";
import { anchors, links } from "@/config/site";
import { header, nav } from "@/content/landing";
import styles from "./SiteHeader.module.css";

/** The top bar on the hero's black: wordmark, section links, Log in and Get started. */
export function SiteHeader() {
  return (
    <Container as="header" className={styles.header}>
      <Wordmark tone="white" href={`#${anchors.top}`} />
      <nav aria-label="Main" className={styles.nav}>
        {nav.map((item) => (
          <a key={item.href} href={item.href}>
            {item.label}
          </a>
        ))}
      </nav>
      <div className={styles.actions}>
        <ButtonLink href={links.webApp} variant="ghost">
          {header.logIn}
        </ButtonLink>
        <ButtonLink href={`#${anchors.get}`} variant="light">
          {header.getStarted}
        </ButtonLink>
      </div>
    </Container>
  );
}

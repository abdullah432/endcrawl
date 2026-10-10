import { Container } from "@/components/ui/Container";
import { Wordmark } from "@/components/ui/Wordmark";
import { site } from "@/config/site";
import { footer, footerNav } from "@/content/landing";
import styles from "./SiteFooter.module.css";

export function SiteFooter() {
  return (
    <footer className={styles.footer}>
      <Container className={styles.top}>
        <div className={styles.brand}>
          <Wordmark />
          <p className={styles.tagline}>{footer.tagline}</p>
        </div>
        <nav aria-label="Footer" className={styles.nav}>
          {footerNav.map((item) => {
            const external = /^https?:/.test(item.href);
            return (
              <a key={item.label} href={item.href} {...(external ? { target: "_blank", rel: "noopener noreferrer" } : {})}>
                {item.label}
              </a>
            );
          })}
        </nav>
      </Container>
      <Container className={styles.legal}>
        <span>
          © {site.year} {site.name}
        </span>
        <span>{footer.trademark}</span>
      </Container>
    </footer>
  );
}

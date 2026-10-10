import { Container } from "@/components/ui/Container";
import { DisplayHeading } from "@/components/ui/DisplayHeading";
import { anchors } from "@/config/site";
import { faq } from "@/content/landing";
import styles from "./Faq.module.css";

/**
 * Native disclosure widgets: keyboard, screen reader and find-in-page
 * support come free, and they work before any script loads.
 */
export function Faq() {
  return (
    <Container as="section" width="text" id={anchors.faq} className={styles.section} aria-labelledby="faq-title">
      <DisplayHeading heading={faq.heading} id="faq-title" />
      <div className={styles.list}>
        {faq.items.map((item) => (
          <details key={item.q} className={styles.item}>
            <summary className={styles.question}>
              <span>{item.q}</span>
              <span className={styles.plus} aria-hidden="true">
                +
              </span>
            </summary>
            <p className={styles.answer}>{item.a}</p>
          </details>
        ))}
      </div>
    </Container>
  );
}

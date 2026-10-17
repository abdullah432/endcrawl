import { Container } from "@/components/ui/Container";
import { madeFor } from "@/content/landing";
import styles from "./MadeFor.module.css";

/** Who it's for, as a row of serif pills, and the templates that start each one. */
export function MadeFor() {
  return (
    <Container as="section" className={styles.section} aria-labelledby="made-for-title">
      <h2 id="made-for-title" className={styles.title}>
        {madeFor.eyebrow}
      </h2>
      <ul className={styles.pills}>
        {madeFor.items.map((item) => (
          <li key={item}>{item}</li>
        ))}
      </ul>
      <p className={styles.body}>{madeFor.body}</p>
    </Container>
  );
}

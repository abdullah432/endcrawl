import { Container } from "@/components/ui/Container";
import { DisplayHeading } from "@/components/ui/DisplayHeading";
import { Eyebrow } from "@/components/ui/Eyebrow";
import { problem } from "@/content/landing";
import styles from "./Problem.module.css";

/** The pain, told as a credit roll: “Also starring” the things that go wrong. */
export function Problem() {
  return (
    <Container as="section" className={styles.section} aria-labelledby="problem-title">
      <div className={styles.copy}>
        <Eyebrow>{problem.eyebrow}</Eyebrow>
        <DisplayHeading heading={problem.heading} id="problem-title" />
        <p className={styles.body}>{problem.body}</p>
      </div>
      <div className={styles.card} data-surface="dark">
        <Eyebrow face="credit" tone="dim" className={styles.cardHead}>
          {problem.cardHead}
        </Eyebrow>
        <dl className={styles.list}>
          {problem.pains.map((p) => (
            <div key={p.role} className={styles.row}>
              <dt>{p.role}</dt>
              <dd>{p.name}</dd>
            </div>
          ))}
        </dl>
        <Eyebrow face="credit" tone="sky" className={styles.cardFoot}>
          {problem.cardFoot}
        </Eyebrow>
      </div>
    </Container>
  );
}

import { Container } from "@/components/ui/Container";
import { DisplayHeading } from "@/components/ui/DisplayHeading";
import { SectionIntro } from "@/components/ui/SectionIntro";
import { anchors } from "@/config/site";
import { howItWorks } from "@/content/landing";
import { StepVisual } from "./StepVisual";
import styles from "./HowItWorks.module.css";

/** Six brisk benefits, each with a small picture of the app doing it. */
export function HowItWorks() {
  return (
    <section id={anchors.how} className={styles.band} aria-labelledby="how-title">
      <Container className={styles.inner}>
        <SectionIntro
          heading={<DisplayHeading heading={howItWorks.heading} id="how-title" className={styles.title} />}
          intro={howItWorks.intro}
        />
        <ol className={styles.grid}>
          {howItWorks.steps.map((step, i) => (
            <li key={step.title} className={styles.step}>
              <StepVisual kind={step.visual} alt={step.alt} />
              <span className={styles.number} aria-hidden="true">
                {String(i + 1).padStart(2, "0")}
              </span>
              <DisplayHeading heading={{ text: step.title }} level={3} size="step" />
              <p className={styles.body}>{step.body}</p>
            </li>
          ))}
        </ol>
      </Container>
    </section>
  );
}

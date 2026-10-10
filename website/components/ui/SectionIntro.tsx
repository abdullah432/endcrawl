import type { ReactNode } from "react";
import styles from "./SectionIntro.module.css";

/** A section's heading with its short intro beside it, wrapping under on narrow screens. */
export function SectionIntro({ heading, intro }: { heading: ReactNode; intro: string }) {
  return (
    <div className={styles.intro}>
      {heading}
      <p className={styles.text}>{intro}</p>
    </div>
  );
}

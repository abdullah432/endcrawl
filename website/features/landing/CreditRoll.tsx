import type { CreditLine } from "@/content/landing";
import { RollControl } from "./RollControl";
import styles from "./CreditRoll.module.css";

function Credits({ lines }: { lines: CreditLine[] }) {
  return (
    <div className={styles.loop}>
      {lines.map((line, i) => {
        switch (line.kind) {
          case "head":
            return <div key={i} className={styles.head}>{line.text}</div>;
          case "name":
            return <div key={i} className={styles.name}>{line.text}</div>;
          case "pair":
            return (
              <div key={i} className={styles.pair}>
                <span className={styles.role}>{line.role}</span>
                <span className={styles.pairName}>{line.name}</span>
              </div>
            );
          case "gap":
            return <div key={i} className={styles.gap} />;
        }
      })}
    </div>
  );
}

type Props = { lines: CreditLine[]; status: string; stamp: string };

/**
 * A credit roll in a 2.39:1 frame. The list runs twice and slides up by
 * half its height, so the loop is seamless. Purely visual: screen readers
 * get one sentence instead of every name. Stills under reduced motion.
 */
export function CreditRoll({ lines, status, stamp }: Props) {
  return (
    <figure className={styles.frame}>
      <figcaption className="visually-hidden">A sample end credit roll made in LastReel, scrolling smoothly.</figcaption>
      <div className={styles.mask} aria-hidden="true">
        <div className={styles.roll} data-roll>
          <Credits lines={lines} />
          <Credits lines={lines} />
        </div>
      </div>
      <span className={styles.status} aria-hidden="true">
        <span className={styles.dot} />
        {status}
      </span>
      <span className={styles.stamp} aria-hidden="true">
        {stamp}
      </span>
      <RollControl />
    </figure>
  );
}

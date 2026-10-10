import type { StepVisual as Kind } from "@/content/landing";
import { howItWorks as content } from "@/content/landing";
import styles from "./StepVisual.module.css";

/** Paste → split: raw lines on the left, parsed fields on the right, one line flagged. */
function Paste() {
  return (
    <div className={`${styles.panel} ${styles.paste}`}>
      <div className={styles.raw}>
        {content.rawLines.map((l) => (
          <span key={l}>{l}</span>
        ))}
        <span className={styles.flagged}>{content.flaggedLine}</span>
      </div>
      <div className={styles.parsed}>
        {content.parsed.map((r) => (
          <div key={r.role} className={styles.field}>
            <span className={styles.fieldRole}>{r.role}</span>
            <span className={styles.fieldName}>{r.name}</span>
          </div>
        ))}
        <span className={styles.flagChip}>Line 5 needs a look</span>
      </div>
    </div>
  );
}

function Runtime() {
  return (
    <div className={`${styles.panel} ${styles.runtime}`}>
      <span className={styles.small}>Runtime · the input</span>
      <span className={styles.clock}>
        00:02:41<span className={styles.frames}>:00</span>
      </span>
      <span className={styles.derived}>Derived · 4.00 px/frame</span>
      <div className={styles.verdicts}>
        <span className={styles.ok}>✓ No judder</span>
        <span className={styles.ok}>✓ Readable · 4.6s</span>
      </div>
    </div>
  );
}

function Blocks() {
  return (
    <div className={`${styles.panel} ${styles.blocks}`}>
      {content.blockChips.map(([code, name]) => (
        <span key={code} className={styles.chip}>
          <span className={styles.code}>{code}</span>
          {name}
        </span>
      ))}
    </div>
  );
}

function Fix() {
  return (
    <div className={`${styles.panel} ${styles.fix}`}>
      <span className={styles.fixHead}>Editor</span>
      <s className={styles.wrong}>Bruno Takahasi</s>
      <span className={styles.right}>Bruno Takahashi</span>
      <span className={styles.rendered}>● Rendered again · 4 min</span>
    </div>
  );
}

function Codecs() {
  return (
    <div className={`${styles.panel} ${styles.codecs}`}>
      {content.codecs.map((c) => (
        <div key={c.name} className={styles.codec}>
          <span>{c.name}</span>
          <span className={c.plan === "free" ? styles.free : styles.pro}>{c.plan.toUpperCase()}</span>
        </div>
      ))}
    </div>
  );
}

/** The web app in miniature: blocks, monitor, settings over a timeline. */
function Desk() {
  return (
    <div className={`${styles.panel} ${styles.desk}`}>
      <div className={styles.lights}>
        <span />
        <span />
        <span />
      </div>
      <div className={styles.panes}>
        <span />
        <span />
        <span />
      </div>
      <div className={styles.timeline}>
        <span style={{ flex: 1 }} />
        <span style={{ flex: 6 }} className={styles.selected} />
        <span style={{ flex: 4 }} />
        <span style={{ flex: 2 }} />
      </div>
    </div>
  );
}

const visuals: Record<Kind, () => React.JSX.Element> = {
  paste: Paste,
  runtime: Runtime,
  blocks: Blocks,
  fix: Fix,
  codecs: Codecs,
  desk: Desk,
};

/** Each step's illustration, drawn from real app screens, announced as one image. */
export function StepVisual({ kind, alt }: { kind: Kind; alt: string }) {
  const Visual = visuals[kind];
  return (
    <div role="img" aria-label={alt} className={styles.frame}>
      <Visual />
    </div>
  );
}

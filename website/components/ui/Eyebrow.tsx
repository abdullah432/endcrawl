import type { ReactNode } from "react";
import styles from "./Eyebrow.module.css";

type Props = {
  children: ReactNode;
  /** Muted on light sections; sky on black. */
  tone?: "muted" | "sky" | "dim";
  /** Mono for labels; credit for the roll's letterspaced heads. */
  face?: "mono" | "credit";
  className?: string;
};

/** The small uppercase label above a heading, set like a credit head. */
export function Eyebrow({ children, tone = "muted", face = "mono", className }: Props) {
  return <span className={[styles.eyebrow, styles[tone], styles[face], className].filter(Boolean).join(" ")}>{children}</span>;
}

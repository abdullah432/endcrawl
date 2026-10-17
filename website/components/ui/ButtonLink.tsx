import type { ComponentPropsWithoutRef } from "react";
import styles from "./ButtonLink.module.css";

type Props = ComponentPropsWithoutRef<"a"> & {
  /**
   * light — white on black · ghost — text only on black · outline — on light
   * · outlineDark — on black · primary — the blue-violet gradient.
   */
  variant?: "light" | "ghost" | "outline" | "outlineDark" | "primary";
  size?: "md" | "lg" | "store";
  block?: boolean;
};

/** A link styled as a button. Every call to action on the page navigates, so these are anchors. */
export function ButtonLink({ variant = "light", size = "md", block, className, ...rest }: Props) {
  const external = typeof rest.href === "string" && /^https?:/.test(rest.href);
  return (
    <a
      {...(external ? { target: "_blank", rel: "noopener noreferrer" } : {})}
      {...rest}
      className={[styles.button, styles[variant], styles[size], block && styles.block, className].filter(Boolean).join(" ")}
    />
  );
}

import type { Heading } from "@/content/landing";
import styles from "./DisplayHeading.module.css";

type Props = {
  heading: Heading;
  level?: 1 | 2 | 3;
  size?: "hero" | "section" | "closing" | "card" | "step";
  className?: string;
  id?: string;
};

/** A serif display heading whose second half is set in italic, as every heading in the design is. */
export function DisplayHeading({ heading, level = 2, size = "section", className, id }: Props) {
  const Tag = `h${level}` as const;
  return (
    <Tag id={id} className={[styles.heading, styles[size], className].filter(Boolean).join(" ")}>
      {heading.text}
      {heading.emphasis && (
        <>
          {" "}
          <em>{heading.emphasis}</em>
        </>
      )}
      {heading.after && <> {heading.after}</>}
    </Tag>
  );
}

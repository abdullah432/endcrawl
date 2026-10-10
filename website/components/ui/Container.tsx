import type { ComponentPropsWithoutRef, ElementType } from "react";
import styles from "./Container.module.css";

type Props<T extends ElementType> = {
  as?: T;
  width?: "page" | "text";
} & ComponentPropsWithoutRef<T>;

/** Centres content at the page width (1280) or reading width (900), inside the side gutter. */
export function Container<T extends ElementType = "div">({ as, width = "page", className, ...rest }: Props<T>) {
  const Tag: ElementType = as ?? "div";
  return <Tag className={[styles.container, styles[width], className].filter(Boolean).join(" ")} {...rest} />;
}

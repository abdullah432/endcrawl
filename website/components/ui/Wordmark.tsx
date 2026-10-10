import styles from "./Wordmark.module.css";

/** “LASTREEL”, letterspaced like a credit — on black or on paper. */
export function Wordmark({ tone = "ink", href }: { tone?: "ink" | "white"; href?: string }) {
  const className = `${styles.wordmark} ${styles[tone]}`;
  return href ? (
    <a href={href} className={className} aria-label="LastReel home">
      Lastreel
    </a>
  ) : (
    <span className={className}>Lastreel</span>
  );
}

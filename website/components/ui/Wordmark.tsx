import Image from "next/image";
import appIcon from "@/assets/brand/app-icon.png";
import styles from "./Wordmark.module.css";

/** The shared app mark and wordmark, on black or on paper. */
export function Wordmark({ tone = "ink", href }: { tone?: "ink" | "white"; href?: string }) {
  const className = `${styles.wordmark} ${styles[tone]}`;
  const content = (
    <>
      <Image src={appIcon} alt="" width={32} height={32} className={styles.icon} unoptimized />
      <span>Lastreel</span>
    </>
  );
  return href ? (
    <a href={href} className={className} aria-label="LastReel home">
      {content}
    </a>
  ) : (
    <span className={className}>{content}</span>
  );
}

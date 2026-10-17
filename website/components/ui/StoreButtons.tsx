import type { ReactNode } from "react";
import { links } from "@/config/site";
import { stores } from "@/content/landing";
import { ButtonLink } from "./ButtonLink";
import styles from "./StoreButtons.module.css";

/** Google Play, the only store today. */
export function GooglePlayButton() {
  return (
    <ButtonLink href={links.googlePlay} size="store" variant="light" aria-label="Get LastReel on Google Play">
      <svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
        <path d="M6 3.5v17l14-8.5z" />
      </svg>
      <span className={styles.stack}>
        <span className={styles.kicker}>{stores.googlePlay.kicker}</span>
        <span className={styles.name}>{stores.googlePlay.name}</span>
      </span>
    </ButtonLink>
  );
}

/** iPhone & iPad — not a link: there is nowhere to go yet. */
export function IosComingSoon() {
  return (
    <p className={styles.soon}>
      <span className={styles.soonName}>{stores.ios.name}</span>
      <span className={styles.soonStatus}>{stores.ios.status}</span>
    </p>
  );
}

/** A centred, wrapping row of store and app buttons. */
export function StoreRow({ children, id }: { children: ReactNode; id?: string }) {
  return (
    <div id={id} className={styles.row}>
      {children}
    </div>
  );
}

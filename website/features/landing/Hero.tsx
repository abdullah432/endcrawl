import { Container } from "@/components/ui/Container";
import { DisplayHeading } from "@/components/ui/DisplayHeading";
import { Eyebrow } from "@/components/ui/Eyebrow";
import { GooglePlayButton, IosComingSoon, StoreRow } from "@/components/ui/StoreButtons";
import { anchors } from "@/config/site";
import { hero, heroCredits } from "@/content/landing";
import { CreditRoll } from "./CreditRoll";
import { SiteHeader } from "./SiteHeader";
import styles from "./Hero.module.css";

/** Black, because the picture is the pitch: headline, stores, and a roll running underneath. */
export function Hero() {
  return (
    <div className={styles.hero} data-surface="dark">
      <div className={styles.glow} aria-hidden="true" />
      <SiteHeader />
      <Container as="section" id={anchors.top} className={styles.body} aria-labelledby="hero-title">
        <Eyebrow tone="sky" className={styles.eyebrow}>
          {hero.eyebrow}
        </Eyebrow>
        <DisplayHeading heading={hero.heading} level={1} size="hero" id="hero-title" />
        <p className={styles.lede}>{hero.lede}</p>
        <StoreRow id={anchors.get}>
          <GooglePlayButton />
          <IosComingSoon />
        </StoreRow>
        <p className={styles.footnote}>{hero.footnote}</p>
        <CreditRoll lines={heroCredits} status={hero.rollStatus} stamp={hero.rollStamp} />
      </Container>
    </div>
  );
}

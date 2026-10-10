import { ButtonLink } from "@/components/ui/ButtonLink";
import { Container } from "@/components/ui/Container";
import { DisplayHeading } from "@/components/ui/DisplayHeading";
import { Eyebrow } from "@/components/ui/Eyebrow";
import { GooglePlayButton, StoreRow } from "@/components/ui/StoreButtons";
import { links } from "@/config/site";
import { closing } from "@/content/landing";
import styles from "./Closing.module.css";

/** The closing card: one last call to roll, from the phone or the desk. */
export function Closing() {
  return (
    <section className={styles.band} data-surface="dark" aria-labelledby="closing-title">
      <Container className={styles.inner}>
        <Eyebrow face="credit" tone="dim" className={styles.eyebrow}>
          {closing.eyebrow}
        </Eyebrow>
        <DisplayHeading heading={closing.heading} size="closing" id="closing-title" />
        <StoreRow>
          <GooglePlayButton />
          <ButtonLink href={links.webApp} size="store" variant="outlineDark">
            {closing.webApp}
          </ButtonLink>
        </StoreRow>
        <Eyebrow face="credit" tone="sky" className={styles.signoff}>
          {closing.signoff}
        </Eyebrow>
      </Container>
    </section>
  );
}

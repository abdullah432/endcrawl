import { ButtonLink } from "@/components/ui/ButtonLink";
import { Container } from "@/components/ui/Container";
import { DisplayHeading } from "@/components/ui/DisplayHeading";
import { SectionIntro } from "@/components/ui/SectionIntro";
import { anchors, links, webBillingAvailable } from "@/config/site";
import { plans } from "@/content/landing";
import styles from "./Plans.module.css";

type Plan = (typeof plans)["free"];

function PlanCard({ plan, tone }: { plan: Plan; tone: "free" | "pro" }) {
  const pro = tone === "pro";
  return (
    <article className={`${styles.card} ${styles[tone]}`} aria-labelledby={`plan-${tone}`} {...(pro ? { "data-surface": "dark" } : {})}>
      <header>
        <p className={styles.label}>{plan.label}</p>
        <DisplayHeading heading={{ text: plan.title }} level={3} size="card" id={`plan-${tone}`} className={styles.title} />
      </header>
      {pro && <div className={styles.pricing}>
        <p><strong>US$4.99</strong> / month</p>
        <p><strong>US$29.99</strong> / year</p>
        <small>{webBillingAvailable ? "Web pricing." : "Planned web pricing · web checkout is not live yet."} Annual billing is one yearly payment. Renews until cancelled. Taxes and final currency are shown at checkout. Native store prices may differ.</small>
      </div>}
      <ul className={styles.list}>
        {plan.items.map((item) => (
          <li key={item}>
            <span className={styles.mark} aria-hidden="true">
              {pro ? "+" : "✓"}
            </span>
            {item}
          </li>
        ))}
      </ul>
      <ButtonLink href={pro && webBillingAvailable ? links.subscribe : `#${anchors.get}`} size="lg" block variant={pro ? "primary" : "outline"} className={styles.cta}>
        {plan.cta}
      </ButtonLink>
    </article>
  );
}

/** Published catalog pricing is separate from the live checkout availability gate. */
export function Plans() {
  return (
    <Container as="section" id={anchors.plans} className={styles.section} aria-labelledby="plans-title">
      <SectionIntro heading={<DisplayHeading heading={plans.heading} id="plans-title" />} intro={plans.intro} />
      <div className={styles.grid}>
        <PlanCard plan={plans.free} tone="free" />
        <PlanCard plan={plans.pro} tone="pro" />
      </div>
    </Container>
  );
}

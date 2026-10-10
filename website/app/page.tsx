import { Closing } from "@/features/landing/Closing";
import { Faq } from "@/features/landing/Faq";
import { Hero } from "@/features/landing/Hero";
import { HowItWorks } from "@/features/landing/HowItWorks";
import { MadeFor } from "@/features/landing/MadeFor";
import { Plans } from "@/features/landing/Plans";
import { Problem } from "@/features/landing/Problem";
import { SiteFooter } from "@/features/landing/SiteFooter";

export default function Home() {
  return (
    <>
      <main>
        <Hero />
        <Problem />
        <HowItWorks />
        <MadeFor />
        <Plans />
        <Faq />
        <Closing />
      </main>
      <SiteFooter />
    </>
  );
}

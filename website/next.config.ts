import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // A fully static site: `next build` writes plain files to out/ for Firebase Hosting.
  output: "export",
};

export default nextConfig;

"use client";

import { useState } from "react";
import styles from "./RollControl.module.css";

/**
 * Pause and play for the hero roll — moving content needs a way to stop
 * it. Toggles a class on the surrounding figure so the roll itself stays a
 * server-rendered, CSS-only animation. Hidden under reduced motion, where
 * the roll doesn't move.
 */
export function RollControl() {
  const [paused, setPaused] = useState(false);
  return (
    <button
      type="button"
      className={styles.control}
      aria-pressed={paused}
      onClick={(e) => {
        const next = !paused;
        e.currentTarget.closest("figure")?.classList.toggle("roll-paused", next);
        setPaused(next);
      }}
    >
      <svg width="12" height="12" viewBox="0 0 12 12" fill="currentColor" aria-hidden="true">
        {paused ? <path d="M3 1.5v9l7.5-4.5z" /> : <path d="M2.5 1.5h2.5v9H2.5zM7 1.5h2.5v9H7z" />}
      </svg>
      <span className="visually-hidden">Pause the credit roll</span>
    </button>
  );
}

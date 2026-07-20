import { defineConfig, globalIgnores } from "eslint/config";
import nextVitals from "eslint-config-next/core-web-vitals";
import nextTs from "eslint-config-next/typescript";

const eslintConfig = defineConfig([
  ...nextVitals,
  ...nextTs,
  // Override default ignores of eslint-config-next.
  globalIgnores([
    // Default ignores of eslint-config-next:
    ".next/**",
    "out/**",
    "build/**",
    // Isolated Git worktrees can contain their own generated output. They are
    // independently linted from their own root and must not affect main.
    "worktrees/**",
    "next-env.d.ts",
  ]),
]);

export default eslintConfig;

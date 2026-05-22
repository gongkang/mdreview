import { defineConfig, devices } from "@playwright/test";

export default defineConfig({
  testDir: "tests/e2e",
  timeout: 30_000,
  use: {
    ...devices["Desktop Chrome"],
    viewport: { width: 1280, height: 800 }
  }
});

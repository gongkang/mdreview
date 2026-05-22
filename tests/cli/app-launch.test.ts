import { describe, expect, it } from "vitest";
import { resolveAppLaunchArgs } from "../../src/cli/app-launch";

describe("resolveAppLaunchArgs", () => {
  it("uses MDREVIEW_APP_PATH when provided", async () => {
    const args = await resolveAppLaunchArgs({
      env: { MDREVIEW_APP_PATH: "/tmp/mdreview.app" },
      home: "/Users/tester",
      pathExists: async () => true
    });

    expect(args).toEqual(["/tmp/mdreview.app"]);
  });

  it("uses the user Applications app without requiring an env var", async () => {
    const args = await resolveAppLaunchArgs({
      env: {},
      home: "/Users/tester",
      pathExists: async (candidate) => candidate === "/Users/tester/Applications/mdreview.app"
    });

    expect(args).toEqual(["/Users/tester/Applications/mdreview.app"]);
  });

  it("falls back to Launch Services when no known app path exists", async () => {
    const args = await resolveAppLaunchArgs({
      env: {},
      home: "/Users/tester",
      pathExists: async () => false
    });

    expect(args).toEqual(["-a", "mdreview"]);
  });
});

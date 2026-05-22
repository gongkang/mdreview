import { describe, expect, it } from "vitest";
import { createInstallPlan } from "../../scripts/install-local.mjs";

describe("createInstallPlan", () => {
  it("installs the app into the user's Applications directory and links the CLI", () => {
    const plan = createInstallPlan({ root: "/repo", home: "/Users/tester" });

    expect(plan.appSource).toBe("/repo/native/dist/mdreview.app");
    expect(plan.appTarget).toBe("/Users/tester/Applications/mdreview.app");
    expect(plan.linkCommand).toEqual({ command: "npm", args: ["link"], cwd: "/repo" });
  });
});

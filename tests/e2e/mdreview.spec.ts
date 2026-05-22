import { expect, test } from "@playwright/test";
import path from "node:path";
import { startPreviewServer, type StartedPreviewServer } from "../../src/server/http-server";
import { createPreviewSession } from "../../src/server/session";

let server: StartedPreviewServer | undefined;

test.afterEach(async () => {
  await server?.close();
  server = undefined;
});

test("directory mode shows file tree, rendered document, and outline", async ({ page }) => {
  const root = path.resolve("tests/fixtures/docs");
  const session = await createPreviewSession(root);
  server = await startPreviewServer({ session, staticDir: path.resolve("dist/client") });

  await page.goto(`${server.url}/#token=${session.token}`);
  await expect(page.getByLabel("Markdown files")).toBeVisible();
  await expect(page.getByRole("heading", { name: "Fixture Docs" })).toBeVisible();
  await expect(page.getByLabel("On this page")).toContainText("Fixture Docs");
});

test("single-file mode hides file tree", async ({ page }) => {
  const file = path.resolve("tests/fixtures/docs/README.md");
  const session = await createPreviewSession(file);
  server = await startPreviewServer({ session, staticDir: path.resolve("dist/client") });

  await page.goto(`${server.url}/#token=${session.token}`);
  await expect(page.getByLabel("Markdown files")).toHaveCount(0);
  await expect(page.getByRole("heading", { name: "Fixture Docs" })).toBeVisible();
});

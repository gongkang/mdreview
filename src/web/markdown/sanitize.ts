import { defaultSchema } from "rehype-sanitize";

export const markdownSanitizeSchema = {
  ...defaultSchema,
  attributes: {
    ...defaultSchema.attributes,
    code: [["className", /^language-[\w-]+$/]],
    span: [["className", /^hljs-.*$/]],
    input: [["type", "checkbox"], ["checked"], ["disabled"]]
  }
};

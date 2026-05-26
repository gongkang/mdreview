import { defaultSchema } from "rehype-sanitize";

export const markdownSanitizeSchema = {
  ...defaultSchema,
  protocols: {
    ...defaultSchema.protocols,
    src: [...(defaultSchema.protocols?.src ?? []), "mdreview-resource"]
  },
  attributes: {
    ...defaultSchema.attributes,
    code: [["className", /^language-[\w-]+$/]],
    span: [["className", /^hljs-.*$/]],
    input: [["type", "checkbox"], ["checked"], ["disabled"]]
  }
};

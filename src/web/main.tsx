import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { RendererApp } from "./renderer/RendererApp";
import "./styles.css";

createRoot(document.getElementById("root") as HTMLElement).render(
  <StrictMode>
    <RendererApp />
  </StrictMode>
);

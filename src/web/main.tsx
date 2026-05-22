import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { App } from "./App";
import { RendererApp } from "./renderer/RendererApp";
import "./styles.css";

const Root = window.location.protocol === "file:" ? RendererApp : App;

createRoot(document.getElementById("root") as HTMLElement).render(
  <StrictMode>
    <Root />
  </StrictMode>
);

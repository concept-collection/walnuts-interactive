import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
// Import the bridge first so `window.setup` is defined before the host's
// bootstrap calls it (it defers to DOMContentLoaded, after module scripts run).
import "./bridge.js";
import { App } from "./App.js";

createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <App />
  </StrictMode>
);

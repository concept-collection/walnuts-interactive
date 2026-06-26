import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import { viteSingleFile } from "vite-plugin-singlefile";

// Builds the whole app (JS + CSS) inlined into a single dist/index.html, so the
// numbl `.m` can read it with `fileread` and pass it to uihtml (HTMLSource) —
// no supporting files, works in numbl (browser and CLI) and real MATLAB.
export default defineConfig({
  plugins: [react(), viteSingleFile()],
  build: {
    target: "esnext",
    cssCodeSplit: false,
    assetsInlineLimit: 100_000_000,
    chunkSizeWarningLimit: 100_000_000,
  },
});

import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
  plugins: [react()],
  build: {
    outDir: "../backend/static",
    emptyOutDir: true,
  },
  server: {
    proxy: {
      "/chat": "http://localhost:8000",
      "/health": "http://localhost:8000",
      "/agents": "http://localhost:8000",
    },
  },
});

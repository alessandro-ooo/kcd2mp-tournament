import react from "@vitejs/plugin-react";
import { defineConfig } from "vite";

// https://vite.dev/config/
export default defineConfig({
  base: "./",
  plugins: [react()],
  build: {
    outDir: "../bin/test", // kcd2mp's ui folder
    emptyOutDir: true,
  },
});

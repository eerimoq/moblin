import { defineConfig } from "vite";
import solidPlugin from "vite-plugin-solid";
import { resolve } from "path";
import { fileURLToPath } from "url";

const __dirname = fileURLToPath(new URL(".", import.meta.url));

export default defineConfig({
  plugins: [solidPlugin()],
  publicDir: resolve(__dirname, "../Web"),
  build: {
    outDir: resolve(__dirname, "../Web"),
    emptyOutDir: false,
    rollupOptions: {
      input: {
        index: resolve(__dirname, "index.html"),
        remote: resolve(__dirname, "remote.html"),
        golf: resolve(__dirname, "golf.html"),
        recordings: resolve(__dirname, "recordings.html"),
        scoreboard: resolve(__dirname, "scoreboard.html"),
      },
      external: ["/js/config.mjs"],
      output: {
        entryFileNames: "js/[name].mjs",
        chunkFileNames: "js/[name].mjs",
        assetFileNames: (assetInfo) => {
          if (assetInfo.name && assetInfo.name.endsWith(".css")) {
            return "css/[name][extname]";
          }
          return "[name][extname]";
        },
        manualChunks: (id) => {
          if (id.includes("node_modules")) {
            return "vendor";
          }
          if (id.includes("/src/utils.js")) {
            return "utils";
          }
        },
      },
    },
  },
});

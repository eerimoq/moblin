import { defineConfig } from "vite";
import { svelte } from "@sveltejs/vite-plugin-svelte";
import { resolve } from "path";
import { fileURLToPath } from "url";

const __dirname = fileURLToPath(new URL(".", import.meta.url));

export default defineConfig({
  plugins: [svelte()],
  build: {
    outDir: resolve(__dirname, "../Moblin/RemoteControl/Web"),
    emptyOutDir: false,
    rollupOptions: {
      // config.mjs is generated dynamically by the iOS server at runtime
      external: ["/js/config.mjs"],
      input: {
        index: resolve(__dirname, "index.html"),
        remote: resolve(__dirname, "remote.html"),
        golf: resolve(__dirname, "golf.html"),
        recordings: resolve(__dirname, "recordings.html"),
        scoreboard: resolve(__dirname, "scoreboard.html"),
      },
      output: {
        entryFileNames: "js/[name].js",
        chunkFileNames: "js/[name]-chunk.js",
        assetFileNames: "[name][extname]",
        globals: {
          "/js/config.mjs": "MoblinConfig",
        },
      },
    },
  },
});

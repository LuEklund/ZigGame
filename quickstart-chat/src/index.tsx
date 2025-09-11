import { serve } from "bun";
import { join } from "path";
import index from "./index.html";
import game from "./game.html"

const server = serve({
  port: 4000,
  routes: {
    // Serve index.html for all unmatched routes.
    "/game": game,
    // Game.ts → Game.js compiled in-memory
    "/game.tsx": async () => {
      const build = await Bun.build({
        entrypoints: ["./game.tsx"],
        target: "browser",
      });
      
      return new Response(build.outputs[0], {
        headers: { "Content-Type": "application/javascript" },
      });
    },
    
    // Serve WASM file
    "/ZigGameRuntime.wasm": async () =>
      {
        const wasmPath = join(import.meta.dir, "ZigGameRuntime.wasm");
        const file = Bun.file(wasmPath);

        if (!(await file.exists())) {
          return new Response("WASM not found", { status: 404 });
        }

        return new Response(file, {
          headers: { "Content-Type": "application/wasm" },
        });

    },

    // Serve index.html for React Router (catch-all)
    "/": index,

    "/*": index,

 
  },

  development: process.env.NODE_ENV !== "production" && {
    // Enable browser hot reloading in development
    hmr: true,

    // Echo console logs from the browser to the server
    console: true,
  },
});

console.log(`🚀 Server running at ${server.url}`);

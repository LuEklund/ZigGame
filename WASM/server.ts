// server.ts
import { serve } from "bun";

console.log("🚀 Server running at http://localhost:3000");

serve({
  port: 3000,
  async fetch(req: Request) {
    const url = new URL(req.url);

    // Serve the main HTML page
    if (url.pathname === "/") {
      return new Response(Bun.file("index.html"));
    }

    // 💡 The magic happens here!
    // When the browser asks for game.js...
    if (url.pathname === "/game.js") {
      // ...we build the TypeScript file into JavaScript in memory...
      const build = await Bun.build({
        entrypoints: ['./game.ts'],
        target: 'browser',
      });

      // ...and return the first output file.
      return new Response(build.outputs[0]);
    }

    // Serve the WASM file
    if (url.pathname === "/ZigGameRuntime.wasm") {
      return new Response(Bun.file("ZigGameRuntime.wasm"), {
        headers: { "Content-Type": "application/wasm" },
      });
    }

    // Handle not found
    return new Response("404! Not Found", { status: 404 });
  },
});
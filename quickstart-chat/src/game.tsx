export { }

import App from "./App";
const canvas = document.getElementById("game") as HTMLCanvasElement;
const ctx = canvas.getContext("2d")!;
const width = canvas.width;
const height = canvas.height;


const STATE_SIZE = 32;   // 5 floats, padded
const INPUT_SIZE = 4;    // 4 bools

const STATE_PTR = 0;
const INPUT_PTR = STATE_PTR + STATE_SIZE;
const PIXELS_PTR = INPUT_PTR + INPUT_SIZE + 32; // leave some padding

const wasmResponse = await fetch("./ZigGameRuntime.wasm");
const wasmFile = await wasmResponse.arrayBuffer();

const { instance } = await WebAssembly.instantiate(wasmFile, {});
// webdev pisses me off
console.log("WASM Exports:", instance.exports);

const { memory, update, draw } = instance.exports as {
  memory: WebAssembly.Memory;
  update: (dt: number, statePtr: any, inputPtr: any) => void;
  draw: (statePtr: any, bufferPtr: any) => void;
};


// Helper for debugging memory state
function logMemory(label: string) {
  const pages = memory.buffer.byteLength / 65536;
  console.log(`[${label}] memory pages: ${pages}, size: ${memory.buffer.byteLength} bytes`);
}

// Create fresh views
function createViews() {
  console.log("🔄 Rebuilding views on memory.buffer...");
  return {
    stateView: new DataView(memory.buffer, STATE_PTR, STATE_SIZE),
    inputView: new DataView(memory.buffer, INPUT_PTR, INPUT_SIZE),
    pixelBuffer: new Uint8ClampedArray(memory.buffer, PIXELS_PTR, width * height * 4),
  };
}

let { stateView, inputView, pixelBuffer } = createViews();

// Track input
const input = { w: false, a: false, s: false, d: false };
window.addEventListener("keydown", (e) => { if (e.key in input) input[e.key as keyof typeof input] = true; });
window.addEventListener("keyup", (e) => { if (e.key in input) input[e.key as keyof typeof input] = false; });

function syncInput() {
  inputView.setUint8(0, input.a ? 1 : 0);
  inputView.setUint8(1, input.w ? 1 : 0);
  inputView.setUint8(2, input.s ? 1 : 0);
  inputView.setUint8(3, input.d ? 1 : 0);
}


let lastTime = performance.now();
function frame(now: number) {
  const dt = (now - lastTime) / 1000;
  lastTime = now;

  // Detect memory growth
  if (pixelBuffer.byteLength === 0 || pixelBuffer.buffer !== memory.buffer) {
    console.warn("⚠️ Detected memory growth/realloc!");
    ({ stateView, inputView, pixelBuffer } = createViews());
    logMemory("after grow");
  }

  syncInput();
  update(dt, STATE_PTR, INPUT_PTR);
  draw(STATE_PTR, PIXELS_PTR);

  ctx.putImageData(new ImageData(pixelBuffer, width, height), 0, 0);

  requestAnimationFrame(frame);
}

logMemory("initial")
requestAnimationFrame(frame);

export {}

const canvas = document.getElementById("game") as HTMLCanvasElement;
const ctx = canvas.getContext("2d")!;
const width = canvas.width;
const height = canvas.height;


const STATE_PTR = 0;                 // first bytes for State
const INPUT_PTR = STATE_PTR + 256;    // next chunk for Input
const PIXELS_PTR = 1024;             // somewhere further (enough room for 600*400 pixels)

const wasmResponse = await fetch("./ZigGameRuntime.wasm");
const wasmFile = await wasmResponse.arrayBuffer();

const { instance } = await WebAssembly.instantiate(wasmFile, {});

console.log("WASM Exports:", instance.exports);

const { memory, update, draw } = instance.exports as {
  memory: WebAssembly.Memory;
  update: (dt: number, statePtr: any, inputPtr: any) => void;
  draw: (statePtr: any, bufferPtr: any) => void;
};


// State is 5 floats (20 bytes) — but align to 32
const stateView = new DataView(memory.buffer, STATE_PTR, 32);

// Input is 4 bools (4 bytes)
const inputView = new DataView(memory.buffer, INPUT_PTR, 4);

// Pixels: RGBA u8 each
const pixelBuffer = new Uint8ClampedArray(memory.buffer, PIXELS_PTR, width * height * 4);

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

  syncInput();
  update(dt, STATE_PTR, INPUT_PTR);
  draw(STATE_PTR, PIXELS_PTR);

  ctx.putImageData(new ImageData(pixelBuffer, width, height), 0, 0);

  requestAnimationFrame(frame);
}

requestAnimationFrame(frame);
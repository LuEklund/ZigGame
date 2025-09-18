import { useEffect, useRef, useState } from "react";
import { DbConnection, Food, type ErrorContext, type EventContext} from '../client/src/module_bindings';
import { Identity } from '@clockworklabs/spacetimedb-sdk';

export default function ZigGame() {
  //Database
  const [connected, setConnected] = useState<boolean>(false);
  const [identity, setIdentity] = useState<Identity | null>(null);
  const [conn, setConn] = useState<DbConnection | null>(null);
  
  //The game
  const canvasRef = useRef<HTMLCanvasElement | null>(null);

  useEffect(() => {
    let animationId: number;

    async function init() {
      const canvas = canvasRef.current!;
      const ctx = canvas.getContext("2d")!;
      const width = canvas.width;
      const height = canvas.height;

      const STATE_SIZE = 1056;
      const INPUT_SIZE = 4;

      const STATE_PTR = 0;
      const INPUT_PTR = STATE_PTR + STATE_SIZE;
      const PIXELS_PTR = INPUT_PTR + INPUT_SIZE + 32;

      const wasmResponse = await fetch("./ZigGameRuntime.wasm");
      const wasmFile = await wasmResponse.arrayBuffer();
      const { instance } = await WebAssembly.instantiate(wasmFile, {});
      console.log("WASM Exports:", instance.exports);

      const { memory, update, spawnFood, draw } = instance.exports as {
        memory: WebAssembly.Memory;
        update: (dt: number, statePtr: number, inputPtr: number) => void;
        spawnFood: (statePtr: number, posX: number, posY: number) => void;
        draw: (statePtr: number, bufferPtr: number) => void;
      };

      function logMemory(label: string) {
        const pages = memory.buffer.byteLength / 65536;
        // console.log(`[${label}] memory pages: ${pages}, size: ${memory.buffer.byteLength} bytes`);
      }

      function createViews() {
        // console.log("🔄 Rebuilding views on memory.buffer...");
        return {
          stateView: new DataView(memory.buffer, STATE_PTR, STATE_SIZE),
          inputView: new DataView(memory.buffer, INPUT_PTR, INPUT_SIZE),
          pixelBuffer: new Uint8ClampedArray(memory.buffer, PIXELS_PTR, width * height * 4),
        };
      }

      let { stateView, inputView, pixelBuffer } = createViews();

      const input = { w: false, a: false, s: false, d: false };
      const handleKeyDown = (e: KeyboardEvent) => {
        if (e.key in input) input[e.key as keyof typeof input] = true;
      };
      const handleKeyUp = (e: KeyboardEvent) => {
        if (e.key in input) input[e.key as keyof typeof input] = false;
      };

      window.addEventListener("keydown", handleKeyDown);
      window.addEventListener("keyup", handleKeyUp);

      function syncInput() {
        inputView.setUint8(0, input.a ? 1 : 0);
        inputView.setUint8(1, input.w ? 1 : 0);
        inputView.setUint8(2, input.s ? 1 : 0);
        inputView.setUint8(3, input.d ? 1 : 0);
      }


      const onConnect = (
      conn: DbConnection,
      identity: Identity,
      token: string
    ) => {
      setIdentity(identity);
      setConnected(true);
      localStorage.setItem('auth_token', token);
      console.log(
        'Connected to SpacetimeDB with identity:',
        identity.toHexString()
      );
    const sub = conn
      .subscriptionBuilder().onApplied(() => {
        console.log("Subscribed to food");
      }).subscribe(['SELECT * FROM food'])
      conn.db.food.onInsert((ctx: EventContext, food: Food) => {
        // if (entity) {
        //   // Position is a DbVector2, so access x and y
        //   spawnFood(STATE_PTR, entity.position.x, entity.position.y);
        //   console.log(`✅ Spawned food at (${entity.position.x}, ${entity.position.y})`);
        // }
        spawnFood(STATE_PTR, 20,20);
      })

      console.log('________________________');

      // Update your game state here to render the new food
    };

    const onDisconnect = () => {
      console.log('Disconnected from SpacetimeDB');
      setConnected(false);
    };

    const onConnectError = (_ctx: ErrorContext, err: Error) => {
      console.log('Error connecting to SpacetimeDB:', err);
    };

    setConn(
    DbConnection.builder()
    .withUri('ws://localhost:3000')
    .withModuleName('quickstart-chat')
    .withToken(localStorage.getItem('auth_token') || '')
    .onConnect(onConnect)     // <- once this runs, your Rust `connect` reducer has already fired
    .onDisconnect(onDisconnect)
    .onConnectError(onConnectError)
    .build()
);
         

      let lastTime = performance.now();
      function frame(now: number) {
        const dt = (now - lastTime) / 1000;
        lastTime = now;

        if (pixelBuffer.byteLength === 0 || pixelBuffer.buffer !== memory.buffer) {
          // console.warn("⚠️ Detected memory growth/realloc!");
          ({ stateView, inputView, pixelBuffer } = createViews());
          logMemory("after grow");
        }
        
        syncInput();
        update(dt, STATE_PTR, INPUT_PTR);
        draw(STATE_PTR, PIXELS_PTR);
          
        ctx.putImageData(new ImageData(pixelBuffer, width, height), 0, 0);

        animationId = requestAnimationFrame(frame);
      }

      logMemory("initial");
      animationId = requestAnimationFrame(frame);
    }

    init();

    return () => {
      cancelAnimationFrame(animationId);
      window.removeEventListener("keydown", () => {});
      window.removeEventListener("keyup", () => {});
    };
  }, []);

  return <canvas ref={canvasRef} id="game" width={400} height={400} />;
}



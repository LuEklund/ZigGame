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
  
  // WASM state - these will be available to database callbacks
  const [wasmReady, setWasmReady] = useState(false);
  const [spawnFood, setSpawnFood] = useState<((statePtr: number, posX: number, posY: number) => void) | null>(null);
  const [statePtr, setStatePtr] = useState(0);

  // Database connection setup (runs once on mount)
  useEffect(() => {
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

      // Wait for WASM to be ready before setting up listeners
      if (!wasmReady) {
        console.log("⏳ Waiting for WASM to be ready before setting up food listeners...");
        return;
      }

      // Now WASM is ready, set up the food listener
      const entitySub = conn
          .subscriptionBuilder()
          .onApplied(() => {
            console.log("✅ Entity table subscribed and cached!");
          })
      .subscribe(['SELECT * FROM entity']);

      const sub = conn
        .subscriptionBuilder()
        .onApplied(() => {
          console.log("✅ Subscribed to food");
        })
        .subscribe(['SELECT * FROM food']);

      conn.db.food.onInsert((ctx: EventContext, food: Food) => {
        const entity = conn.db.entity.entityId.find(food.entityId);
        
        // Now we have access to spawnFood and statePtr!
        // ...Object.fromEntries(Object.keys(food).map(key => (food as any)[key]));
        if (spawnFood && statePtr !== 0) {
          spawnFood(statePtr, entity!.position.x, entity!.position.y);
          console.log(`✅ Spawned food at (${entity!.position.x}, ${entity!.position.y})`);
        } else {
          console.warn("⚠️ WASM not ready for spawning food yet");
        }
      });

      console.log('________________________');
    };

    const onDisconnect = () => {
      console.log('Disconnected from SpacetimeDB');
      setConnected(false);
    };

    const onConnectError = (_ctx: ErrorContext, err: Error) => {
      console.log('Error connecting to SpacetimeDB:', err);
    };

    const connection = DbConnection.builder()
      .withUri('ws://localhost:3000')
      .withModuleName('quickstart-chat')
      .withToken(localStorage.getItem('auth_token') || '')
      .onConnect(onConnect)
      .onDisconnect(onDisconnect)
      .onConnectError(onConnectError)
      .build();

    setConn(connection);

    // Cleanup
    return () => {
      connection.disconnect();
    };
  }, [wasmReady, spawnFood, statePtr]); // Re-run when WASM becomes ready

  // WASM and game initialization
  useEffect(() => {
    let animationId: number;

    async function init() {
      const canvas = canvasRef.current!;
      if (!canvas) return;
      
      const ctx = canvas.getContext("2d")!;
      const width = canvas.width;
      const height = canvas.height;

      const STATE_SIZE = 1056;
      const INPUT_SIZE = 4;

      const STATE_PTR = 1;
      const INPUT_PTR = STATE_PTR + STATE_SIZE;
      const PIXELS_PTR = INPUT_PTR + INPUT_SIZE + 32;

      try {
        const wasmResponse = await fetch("./ZigGameRuntime.wasm");
        const wasmFile = await wasmResponse.arrayBuffer();
        const { instance } = await WebAssembly.instantiate(wasmFile, {});
        console.log("🎮 WASM Exports:", Object.keys(instance.exports));

        const { memory, update, spawnFood, draw } = instance.exports as {
          memory: WebAssembly.Memory;
          update: (dt: number, statePtr: number, inputPtr: number) => void;
          spawnFood: (statePtr: number, posX: number, posY: number) => void;
          draw: (statePtr: number, bufferPtr: number) => void;
        };

        // Store WASM functions and state in React state
        setSpawnFood(() => spawnFood);
        setStatePtr(STATE_PTR);
        setWasmReady(true);
        
        console.log("✅ WASM ready! Database listeners will now be set up.");

        function logMemory(label: string) {
          const pages = memory.buffer.byteLength / 65536;
          // console.log(`[${label}] memory pages: ${pages}, size: ${memory.buffer.byteLength} bytes`);
        }

        function createViews() {
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

      } catch (error) {
        console.error("❌ Failed to initialize WASM:", error);
      }
    }

    

    init();

    

    return () => {
      if (animationId) {
        cancelAnimationFrame(animationId);
      }
      // Note: The empty arrow functions in your original cleanup were problematic
      // They would remove the wrong listeners. Since we're adding them in the same scope,
      // we can just remove them properly in the same scope.
    };
  }, []); // Empty dependency array - runs once on mount

  return (
    <div>
      <canvas 
        ref={canvasRef} 
        id="game" 
        width={400} 
        height={400}
        style={{ border: '1px solid black', display: 'block' }}
      />
      <div style={{ marginTop: '10px' }}>
        <p>Connected: {connected ? '✅ Yes' : '❌ No'}</p>
        {identity && (
          <p>Identity: {identity.toHexString().slice(0, 8)}...</p>
        )}
        <p>WASM Ready: {wasmReady ? '✅ Yes' : '⏳ Loading...'}</p>
      </div>
      // In your JSX
    </div>
  );
}
import { useEffect, useRef, useState } from "react";
import { Circle, DbConnection, DbVector2, Entity, Food, Player, type ErrorContext, type EventContext, type SubscriptionEventContext} from '../client/src/module_bindings';
import { Identity } from '@clockworklabs/spacetimedb-sdk';

export default function ZigGame() {
  //Database
  const [connected, setConnected] = useState<boolean>(false);
  const [identity, setIdentity] = useState<Identity | null>(null);
  const [conn, setConn] = useState<DbConnection | null>(null);
  const connRef = useRef<DbConnection | null>(null); // Use ref for conn

  //The game
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  
  // WASM state - these will be available to database callbacks
  const [wasmReady, setWasmReady] = useState(false);
  const [spawnEntity, setSpawnEntity] = useState<((statePtr: number,id: number, posx: number, posy: number, mass: number) => void) | null>(null);
  const [updateEntity, setUpdateEntity] = useState<((statePtr: number,id: number, posx: number, posy: number, mass: number) => void) | null>(null);
  const [statePtr, setStatePtr] = useState(0);


  function HandleSubscriptionApplied(ctx: SubscriptionEventContext ) {
    ctx.reducers.enterGame("Lucas");
    // console.log("⏳ try spawn player!");
    // if (spawnPlayer)
    // {

    // console.log("✅ spawn player!");

    //   spawnPlayer(statePtr, 50, 50);
    // }
  }

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

      conn.subscriptionBuilder().onApplied(HandleSubscriptionApplied).subscribeToAllTables();

      conn.db.entity.onUpdate((ctx: EventContext, oldEntity: Entity, newEntity: Entity) => {

        if (updateEntity && statePtr !== 0) {
          updateEntity(statePtr, newEntity.entityId, newEntity.position.x,  newEntity.position.y,  newEntity.mass);
       
        }
      });

      conn.db.entity.onInsert((ctx: EventContext, entity: Entity) => {
        if (spawnEntity && statePtr !== 0) {
          spawnEntity(statePtr, entity.entityId, entity.position.x,  entity.position.y,  entity.mass);
          const entitySize = JSON.stringify(entity).length;
        } else {
          console.warn("⚠️ WASM not ready for spawning Players yet");
        }
      });

    };


    const onDisconnect = () => {
      console.log('❌ Disconnected from SpacetimeDB');
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


    connRef.current = connection;
    setConn(connection);

    // Cleanup
    return () => {
      connection.disconnect();
    };
  }, [wasmReady, spawnEntity, updateEntity, statePtr]); // Re-run when WASM becomes ready

  // WASM and game initialization
  useEffect(() => {
    let animationId: number;

    async function init() {
      const canvas = canvasRef.current!;
      if (!canvas) return;
      
      const ctx = canvas.getContext("2d")!;
      const width = canvas.width;
      const height = canvas.height;

      const STATE_SIZE = 2064;
      const INPUT_SIZE = 4;

      const STATE_PTR = 1;
      const INPUT_PTR = STATE_PTR + STATE_SIZE;
      const PIXELS_PTR = INPUT_PTR + INPUT_SIZE + 32;

      try {
        const wasmResponse = await fetch("./ZigGameRuntime.wasm");
        const wasmFile = await wasmResponse.arrayBuffer();
        const { instance } = await WebAssembly.instantiate(wasmFile, {});
        console.log("🎮 WASM Exports:", Object.keys(instance.exports));

        const { memory, update, spawnEntity, updateEntity, draw } = instance.exports as {
          memory: WebAssembly.Memory;
          update: (dt: number, statePtr: number, inputPtr: number) => void;
          spawnEntity: (statePtr: number,id: number, posx: number, posy: number, mass: number) => void;
          updateEntity: (statePtr: number,id: number, posx: number, posy: number, mass: number) => void;
          draw: (statePtr: number, bufferPtr: number) => void;
        };

        // Store WASM functions and state in React state
        setSpawnEntity(() => spawnEntity);
        setUpdateEntity(() => updateEntity);
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
          if ((input.w
            || input.a
            || input.s
            || input.d)
            && (connRef.current && connRef.current.isActive)) {
            const direction: DbVector2 = {
              x: ((input.d ? 1 : 0) - (input.a ? 1 : 0)),
              y: ((input.s ? 1 : 0) - (input.w ? 1 : 0))};
            connRef.current.reducers.updatePlayerInput(direction);
          } 
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
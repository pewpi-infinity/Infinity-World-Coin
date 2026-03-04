#!/usr/bin/env bash
# serve_biotuner.sh — one-file Termux installer + local server for Infinity BioTuner demo
# Usage:
#   1) Save this file on your Android device (Termux) as serve_biotuner.sh
#      - Option A (nano):   nano serve_biotuner.sh  -> paste contents -> Ctrl+O, Enter -> Ctrl+X
#      - Option B (curl):   curl -o serve_biotuner.sh "https://example.org/serve_biotuner.sh"
#   2) Make executable: chmod +x serve_biotuner.sh
#   3) Run: ./serve_biotuner.sh 8000
#   4) Open http://127.0.0.1:8000 in your device browser (Chrome/Firefox). Web Bluetooth requires a secure context — localhost is OK.
#
# What this does:
#  - Writes a single file index.html (React + Babel from CDN) into the current directory
#  - Starts a simple HTTP server (python3 preferred, falls back to busybox httpd)
#  - The HTML contains the full single-file React app (no build step)
#
# Notes:
#  - If python3 is not installed: pkg install python
#  - This script is intentionally self-contained: you do NOT need to create a separate index.html yourself.
#  - If you want the server to run in background, run it inside a Termux session manager or use nohup.
#
PORT="${1:-8000}"
OUT="index.html"

cat > "$OUT" <<'HTML'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width,initial-scale=1" />
  <title>Infinity BioTuner — Hosted Demo</title>
  <style>
    :root { --bg:#0b0b0d; --panel:#111217; --muted:#9aa0a6; --accent:#06b6d4; --good:#10b981; --danger:#ef4444; color-scheme:dark; }
    body{background:linear-gradient(180deg,var(--bg),#060607); color:#e6eef3; font-family:system-ui,-apple-system,Segoe UI,Roboto,"Helvetica Neue",Arial; margin:0;padding:18px;}
    .wrap{max-width:1000px;margin:0 auto;display:grid;gap:18px;}
    header{display:flex;justify-content:space-between;align-items:flex-start;}
    h1{margin:0;font-size:20px;}
    .panel{background:rgba(255,255,255,0.03);padding:14px;border-radius:12px;}
    .controls{display:grid;grid-template-columns:1fr 1fr;gap:14px;}
    button{background:var(--accent);border:none;color:#041017;padding:8px 12px;border-radius:10px;cursor:pointer;font-weight:600;}
    .btn-danger{background:var(--danger);color:white;}
    .row{display:flex;gap:10px;align-items:center;flex-wrap:wrap;}
    label{font-size:13px;color:var(--muted);}
    input[type=range]{width:100%;}
    .grid3{display:grid;grid-template-columns:repeat(3,1fr);gap:8px;margin-top:10px;}
    .stat{background:rgba(255,255,255,0.02);padding:10px;border-radius:10px;text-align:center;}
    .spark{width:220px;height:50px;background:rgba(255,255,255,0.02);border-radius:10px;display:block;}
    .muted{color:var(--muted);font-size:12px;}
    .iso-ind{height:8px;border-radius:8px;background:rgba(255,255,255,0.08);overflow:hidden;}
    .iso-fill{height:100%;background:linear-gradient(90deg,var(--accent),#7c3aed);width:40%;}
    footer{opacity:0.6;font-size:12px;}
    @media(max-width:800px){ .controls{grid-template-columns:1fr;} .grid3{grid-template-columns:repeat(3,1fr);} }
  </style>
</head>
<body>
  <div id="root"></div>

  <!-- React + ReactDOM + Babel (for in-browser JSX) -->
  <script src="https://unpkg.com/react@18/umd/react.development.js"></script>
  <script src="https://unpkg.com/react-dom@18/umd/react-dom.development.js"></script>
  <script src="https://unpkg.com/@babel/standalone/babel.min.js"></script>

  <script type="text/babel">
  const { useState, useEffect, useMemo, useRef } = React;

  // small helpers
  const clamp = (v,min,max) => Math.max(min, Math.min(max, v));
  const fmt = (n,d=0) => Number.isFinite(n) ? n.toFixed(d) : "–";

  // Rolling window
  class Ring {
    constructor(n){ this.n=n; this.a=new Array(n); this.i=0; this.len=0; }
    push(x){ this.a[this.i]=x; this.i=(this.i+1)%this.n; this.len=Math.min(this.len+1,this.n); }
    values(){ const out=[]; for(let k=0;k<this.len;k++){ out.push(this.a[(this.i-this.len+k+this.n)%this.n]); } return out; }
  }
  function rmssd(rrMs){
    if(rrMs.length<3) return NaN;
    let s=0,c=0;
    for(let i=1;i<rrMs.length;i++){ const d=rrMs[i]-rrMs[i-1]; s+=d*d; c++; }
    return Math.sqrt(s/c);
  }

  function Spark({data=[], min=0, max=1}){
    const path = useMemo(()=>{
      const w=200,h=40;
      if(!data.length) return {d:"", w, h};
      const dx = w/Math.max(1,data.length-1);
      const mapY = v => h - ((clamp(v,min,max)-min)/(max-min||1))*h;
      let d = `M0 ${mapY(data[0])}`;
      data.forEach((v,i)=> d += ` L${i*dx} ${mapY(v)}`);
      return {d, w, h};
    },[data,min,max]);
    return (
      <svg className="spark" viewBox={`0 0 ${path.w} ${path.h}`}>
        <path d={path.d} stroke="white" strokeWidth="2" fill="none" strokeLinecap="round" strokeLinejoin="round" />
      </svg>
    );
  }

  function App(){
    // audio refs
    const audioCtxRef = useRef(null);
    const masterGainRef = useRef(null);
    const leftGainRef = useRef(null);
    const rightGainRef = useRef(null);
    const lOscRef = useRef(null);
    const rOscRef = useRef(null);
    const isoOscRef = useRef(null);
    const isoGainRef = useRef(null);
    const isoModRef = useRef(null);
    const carrierRef = useRef(null);
    const carrierGainRef = useRef(null);
    const noiseRef = useRef(null);

    // BLE device
    const deviceRef = useRef(null);

    // state
    const [running, setRunning] = useState(false);
    const [mode, setMode] = useState("binaural");
    const [baseHz, setBaseHz] = useState(200);
    const [beatHz, setBeatHz] = useState(10);
    const [volume, setVolume] = useState(0.12);
    const [breathHz, setBreathHz] = useState(0.1);
    const [isoDepth, setIsoDepth] = useState(0.5);
    const [connected, setConnected] = useState(false);
    const [hr, setHr] = useState(NaN);
    const [rmssdMs, setRmssdMs] = useState(NaN);
    const [hrSeries, setHrSeries] = useState([]);
    const rrRing = useRef(new Ring(128));

    useEffect(()=>{ if(volume>0.2) setVolume(0.2); },[volume]);

    const ensureAudio = async ()=>{
      if(audioCtxRef.current) return;
      const Ctx = window.AudioContext || window.webkitAudioContext;
      if(!Ctx) throw new Error("AudioContext not available in this browser.");
      const ctx = new Ctx({ latencyHint: "interactive" });

      const master = ctx.createGain(); master.gain.value = 0.0; master.connect(ctx.destination);
      const leftGain = ctx.createGain(), rightGain = ctx.createGain();
      leftGain.gain.value = 0; rightGain.gain.value = 0;
      leftGain.connect(master); rightGain.connect(master);

      const lOsc = ctx.createOscillator(), rOsc = ctx.createOscillator();
      lOsc.type = "sine"; rOsc.type = "sine";
      lOsc.connect(leftGain); rOsc.connect(rightGain);

      const isoOsc = ctx.createOscillator();
      const isoGain = ctx.createGain(); isoOsc.type="sine"; isoGain.gain.value = 0;
      isoOsc.connect(isoGain);

      const isoMod = ctx.createGain(); isoMod.gain.value = isoDepth;
      isoGain.connect(isoMod);

      const carrier = ctx.createOscillator(); carrier.type="sine"; carrier.frequency.value = baseHz;
      const carrierGain = ctx.createGain(); carrierGain.gain.value = 0;
      carrier.connect(carrierGain).connect(master);
      isoMod.connect(carrierGain.gain);

      // pink-ish noise
      const noise = (() => {
        const b = ctx.createBuffer(1, ctx.sampleRate*2, ctx.sampleRate);
        const d = b.getChannelData(0); let x=0;
        for(let i=0;i<d.length;i++){ x = 0.98*x + (Math.random()*2-1)*0.02; d[i]=x; }
        const s = ctx.createBufferSource(); s.buffer=b; s.loop=true; const g = ctx.createGain(); g.gain.value=0; s.connect(g).connect(master); s.start();
        return g;
      })();

      audioCtxRef.current = ctx;
      masterGainRef.current = master;
      leftGainRef.current = leftGain; rightGainRef.current = rightGain;
      lOscRef.current = lOsc; rOscRef.current = rOsc;
      isoOscRef.current = isoOsc; isoGainRef.current = isoGain; isoModRef.current = isoMod;
      carrierRef.current = carrier; carrierGainRef.current = carrierGain;
      noiseRef.current = noise;

      lOsc.start(); rOsc.start(); isoOsc.start(); carrier.start();
    };

    const start = async () => {
      await ensureAudio();
      const ctx = audioCtxRef.current; if(ctx.state === "suspended") await ctx.resume();
      masterGainRef.current.gain.setTargetAtTime(volume, ctx.currentTime, 0.05);
      setRunning(true);
    };
    const stop = async () => {
      if(!audioCtxRef.current) return;
      const ctx = audioCtxRef.current;
      masterGainRef.current.gain.cancelScheduledValues(ctx.currentTime);
      masterGainRef.current.gain.setValueAtTime(0, ctx.currentTime);
      if(leftGainRef.current) leftGainRef.current.gain.setValueAtTime(0, ctx.currentTime);
      if(rightGainRef.current) rightGainRef.current.gain.setValueAtTime(0, ctx.currentTime);
      if(carrierGainRef.current) carrierGainRef.current.gain.setValueAtTime(0, ctx.currentTime);
      if(isoGainRef.current) isoGainRef.current.gain.setValueAtTime(0, ctx.currentTime);
      if(noiseRef.current) noiseRef.current.gain.setValueAtTime(0, ctx.currentTime);
      setRunning(false);
    };

    // keyboard panic: space -> immediate mute
    useEffect(()=>{
      const h = (e)=>{ if(e.code==="Space"){ e.preventDefault(); stop(); } };
      window.addEventListener("keydown", h);
      return ()=>window.removeEventListener("keydown", h);
    },[]);

    // update audio when state changes
    useEffect(()=>{
      if(!audioCtxRef.current) return;
      const ctx = audioCtxRef.current;
      if(carrierRef.current) carrierRef.current.frequency.setTargetAtTime(clamp(baseHz,80,1000), ctx.currentTime, 0.05);
      if(isoModRef.current) isoModRef.current.gain.setTargetAtTime(clamp(isoDepth,0,1), ctx.currentTime, 0.05);

      if(mode === "binaural"){
        const base = clamp(baseHz, 120, 600);
        const beat = clamp(beatHz, 0.5, 40);
        lOscRef.current.frequency.setTargetAtTime(base, ctx.currentTime, 0.05);
        rOscRef.current.frequency.setTargetAtTime(base+beat, ctx.currentTime, 0.05);
        leftGainRef.current.gain.setTargetAtTime(volume*0.6, ctx.currentTime, 0.05);
        rightGainRef.current.gain.setTargetAtTime(volume*0.6, ctx.currentTime, 0.05);
        isoGainRef.current.gain.setTargetAtTime(0, ctx.currentTime, 0.05);
        carrierGainRef.current.gain.setTargetAtTime(0, ctx.currentTime, 0.05);
        noiseRef.current.gain.setTargetAtTime(0, ctx.currentTime, 0.25);
      } else if(mode === "isochronic"){
        const beat = clamp(beatHz, 0.3, 40);
        isoOscRef.current.frequency.setTargetAtTime(beat, ctx.currentTime, 0.05);
        leftGainRef.current.gain.setTargetAtTime(0, ctx.currentTime, 0.05);
        rightGainRef.current.gain.setTargetAtTime(0, ctx.currentTime, 0.05);
        isoGainRef.current.gain.setTargetAtTime(1.0, ctx.currentTime, 0.05);
        carrierGainRef.current.gain.setTargetAtTime(volume*0.6, ctx.currentTime, 0.05);
        noiseRef.current.gain.setTargetAtTime(volume*0.15, ctx.currentTime, 0.3);
      } else if(mode === "tone"){
        lOscRef.current.frequency.setTargetAtTime(baseHz, ctx.currentTime, 0.05);
        rOscRef.current.frequency.setTargetAtTime(baseHz, ctx.currentTime, 0.05);
        leftGainRef.current.gain.setTargetAtTime(volume*0.5, ctx.currentTime, 0.05);
        rightGainRef.current.gain.setTargetAtTime(volume*0.5, ctx.currentTime, 0.05);
        isoGainRef.current.gain.setTargetAtTime(0, ctx.currentTime, 0.05);
        carrierGainRef.current.gain.setTargetAtTime(0, ctx.currentTime, 0.05);
        noiseRef.current.gain.setTargetAtTime(0, ctx.currentTime, 0.3);
      } else if(mode === "noise"){
        leftGainRef.current.gain.setTargetAtTime(0, ctx.currentTime, 0.05);
        rightGainRef.current.gain.setTargetAtTime(0, ctx.currentTime, 0.05);
        carrierGainRef.current.gain.setTargetAtTime(0, ctx.currentTime, 0.05);
        noiseRef.current.gain.setTargetAtTime(volume*0.5, ctx.currentTime, 0.3);
      }
      masterGainRef.current.gain.setTargetAtTime(clamp(volume,0,0.2), ctx.currentTime, 0.1);
    },[mode, baseHz, beatHz, isoDepth, volume]);

    // breath pacing
    useEffect(()=>{
      if(!audioCtxRef.current) return;
      const ctx = audioCtxRef.current;
      let alive = true;
      const schedule = ()=>{
        if(!alive) return;
        const now = ctx.currentTime;
        const target = clamp(volume,0,0.2);
        const wobble = clamp(0.3*target,0,0.08);
        masterGainRef.current.gain.cancelScheduledValues(now);
        masterGainRef.current.gain.setTargetAtTime(Math.max(0,target-wobble), now, 0.5);
        masterGainRef.current.gain.setTargetAtTime(Math.max(0,target+wobble), now + 1/(breathHz||0.1)/2, 0.5);
      };
      schedule();
      const id = setInterval(schedule, 800);
      return ()=>{ alive=false; clearInterval(id); };
    },[breathHz, volume, running]);

    // BLE connect
    const connectBLE = async () => {
      try{
        const device = await navigator.bluetooth.requestDevice({ filters: [{ services: ["heart_rate"] }], optionalServices: ["device_information"] });
        deviceRef.current = device;
        const server = await device.gatt.connect();
        const svc = await server.getPrimaryService("heart_rate");
        const ch = await svc.getCharacteristic("heart_rate_measurement");
        await ch.startNotifications();
        ch.addEventListener("characteristicvaluechanged", ev => {
          const dv = ev.target.value;
          let idx=0; const flags = dv.getUint8(idx++);
          const hr16 = flags & 0x1;
          const rr = (flags>>4)&0x1;
          let _hr = NaN;
          if(hr16){ _hr = dv.getUint16(idx, true); idx+=2; } else { _hr = dv.getUint8(idx++); }
          setHr(_hr);
          if(rr){
            while(idx+1 < dv.byteLength){
              const rrVal = dv.getUint16(idx, true); idx+=2;
              const ms = (rrVal/1024)*1000;
              rrRing.current.push(ms);
            }
            const vals = rrRing.current.values();
            setRmssdMs(rmssd(vals));
            setHrSeries(s => [...s.slice(-59), _hr]);
          } else {
            setHrSeries(s => [...s.slice(-59), _hr]);
          }
        });
        setConnected(true);
        device.addEventListener("gattserverdisconnected", ()=> setConnected(false));
      }catch(err){
        console.error(err);
        alert("BLE failed: " + (err && err.message ? err.message : err));
      }
    };
    const disconnectBLE = () => {
      try{
        if(deviceRef.current && deviceRef.current.gatt && deviceRef.current.gatt.connected){
          deviceRef.current.gatt.disconnect();
        }
        setConnected(false);
      }catch(e){ console.warn("disconnect failed", e); setConnected(false); }
    };

    // simple adaptive nudges
    useEffect(()=>{
      if(!running) return;
      if(!Number.isFinite(rmssdMs)) return;
      const id = setInterval(()=>{
        setBreathHz(h => clamp(h + (Math.random()*0.02-0.01), 0.08, 0.12));
        setBeatHz(f => clamp(f + (Math.random()*0.6-0.3), 0.5, 20));
        setIsoDepth(d => clamp(d + (Math.random()*0.04-0.02), 0.05, 1.0));
      }, 4000);
      return ()=>clearInterval(id);
    },[running, rmssdMs]);

    // cleanup on unload
    useEffect(()=>{
      return ()=>{
        if(audioCtxRef.current){
          try{ audioCtxRef.current.close(); }catch(e){}
        }
        if(deviceRef.current && deviceRef.current.gatt && deviceRef.current.gatt.connected){
          try{ deviceRef.current.gatt.disconnect(); }catch(e){}
        }
      };
    },[]);

    return (
      <div className="wrap">
        <header>
          <div>
            <h1>Infinity BioTuner — Closed‑Loop Signal Generator</h1>
            <div className="muted">Prototype · Wellness / Biofeedback only</div>
          </div>
          <div className="muted" style={{textAlign:"right"}}>
            <div>Volume capped ≤ 0.2 · Space = PANIC MUTE</div>
            <div className="muted">Serve locally via Termux → open http://127.0.0.1:PORT</div>
          </div>
        </header>

        <div className="panel">
          <div className="row" style={{justifyContent:"flex-start", marginBottom:10}}>
            <button onClick={running ? stop : start} style={{background: running ? 'var(--danger)' : 'var(--good)', color:'#021014'}}>
              {running ? "STOP" : "START"}
            </button>
            <button className="btn-danger" onClick={stop}>Panic Mute</button>
            <button onClick={() => { navigator.clipboard && navigator.clipboard.writeText(window.location.href); }} style={{background:'rgba(255,255,255,0.06)', color:'white'}}>Copy URL</button>
            <div style={{marginLeft:10}} className="muted">Running: {running ? "yes" : "no"}</div>
          </div>

          <div className="controls">
            <div>
              <div style={{marginBottom:8}}>
                <label>Mode</label><br/>
                <select value={mode} onChange={e=>setMode(e.target.value)} style={{padding:8,borderRadius:8,marginTop:6,background:'rgba(255,255,255,0.02)',color:'white',width:'100%'}}>
                  <option value="binaural">Binaural (stereo)</option>
                  <option value="isochronic">Isochronic (AM pulses)</option>
                  <option value="tone">Plain Tone</option>
                  <option value="noise">Pink Noise</option>
                </select>
              </div>

              <div style={{marginTop:8}}>
                <label>Carrier / Base (Hz): {fmt(baseHz,0)}</label>
                <input type="range" min={100} max={600} value={baseHz} onChange={e=>setBaseHz(parseFloat(e.target.value))} />
              </div>

              <div style={{marginTop:8}}>
                <label>Beat / Pulse (Hz): {fmt(beatHz,1)}</label>
                <input type="range" min={0.5} max={20} step={0.1} value={beatHz} onChange={e=>setBeatHz(parseFloat(e.target.value))} />
              </div>

              <div style={{marginTop:8}}>
                <label>Isochronic depth: {fmt(isoDepth,2)}</label>
                <input type="range" min={0.05} max={1} step={0.01} value={isoDepth} onChange={e=>setIsoDepth(parseFloat(e.target.value))} />
                <div className="iso-ind" style={{marginTop:6}}><div className="iso-fill" style={{width: `${Math.round(isoDepth*100)}%`}}></div></div>
                <div className="muted" style={{marginTop:6}}>Depth controls how aggressive AM is for isochronic mode.</div>
              </div>

              <div style={{marginTop:8}}>
                <label>Breath pacing (Hz): {fmt(breathHz,3)} (~6/min)</label>
                <input type="range" min={0.06} max={0.14} step={0.002} value={breathHz} onChange={e=>setBreathHz(parseFloat(e.target.value))} />
              </div>

              <div style={{marginTop:8}}>
                <label>Volume (cap 0.2): {fmt(volume,2)}</label>
                <input type="range" min={0} max={0.2} step={0.005} value={volume} onChange={e=>setVolume(parseFloat(e.target.value))} />
              </div>
            </div>

            <div>
              <div style={{display:"flex",gap:8,alignItems:"center",marginBottom:8}}>
                <button onClick={connectBLE} style={{background: connected ? 'linear-gradient(90deg,#06b6d4,#7c3aed)' : undefined}}>{connected ? "Heart Sensor Connected" : "Connect Heart Sensor (BLE)"}</button>
                <button onClick={() => disconnectBLE()} style={{background:'rgba(255,255,255,0.06)'}}>Disconnect sensor</button>
              </div>
              <div className="muted">Standard BLE Heart Rate Service (0x180D)</div>

              <div className="grid3" style={{marginTop:12}}>
                <div className="stat"><div className="muted">HR</div><div style={{fontSize:18}}>{fmt(hr,0)} <span className="muted" style={{fontSize:12}}>bpm</span></div></div>
                <div className="stat"><div className="muted">RMSSD</div><div style={{fontSize:18}}>{fmt(rmssdMs,0)} <span className="muted" style={{fontSize:12}}>ms</span></div></div>
                <div className="stat"><div className="muted">Mode</div><div style={{fontSize:18}}>{mode}</div></div>
              </div>

              <div style={{marginTop:10}}>
                <Spark data={hrSeries} min={40} max={140} />
                <div className="muted" style={{marginTop:6}}>Heart rate trend (last ~60 samples)</div>
              </div>
            </div>
          </div>
        </div>

        <div className="panel">
          <h3 style={{marginTop:0}}>Guidance & Safety</h3>
          <ul style={{marginTop:6,lineHeight:1.6}}>
            <li>This prototype is for relaxation and biofeedback, not a medical device.</li>
            <li>Audio output is soft‑limited. Stop if you feel discomfort, dizziness, or headache.</li>
            <li>Web Bluetooth requires a secure context: localhost/127.0.0.1 is acceptable in modern browsers.</li>
            <li>Do not operate vehicles or heavy machinery while using entrainment modes.</li>
          </ul>
        </div>

        <footer className="muted">© Infinity · Prototype build. Hosted locally via Termux.</footer>
      </div>
    );
  }

  ReactDOM.createRoot(document.getElementById('root')).render(<App />);
  </script>
</body>
</html>
HTML

echo "Wrote $OUT"
echo
echo "Starting simple HTTP server on port ${PORT}..."
# Try python3 first, then busybox httpd, then fallback to node simple-http-server if available.
if command -v python3 >/dev/null 2>&1; then
  echo "Open this URL on the device browser: http://127.0.0.1:${PORT}/"
  python3 -m http.server "${PORT}"
elif command -v busybox >/dev/null 2>&1 && busybox httpd --help >/dev/null 2>&1; then
  echo "Using busybox httpd"
  busybox httpd -f -p "${PORT}"
elif command -v npx >/dev/null 2>&1; then
  echo "Using npx http-server"
  npx http-server -p "${PORT}"
else
  echo "No suitable HTTP server found (python3, busybox, or npx)."
  echo "Install python: pkg install python"
  exit 1
fi
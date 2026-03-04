import React, { useMemo, useState } from "react";

/**
 * Infinity Field Lab — Ultra‑Lite (ES5‑safe JSX)
 * Fixes "Unexpected token" by avoiding default params in destructuring,
 * exotic unicode in code paths, and any syntax that older parsers dislike.
 * Pure React + inline SVG. No external packages.
 */

// ---------------- helpers ----------------
var TAU = Math.PI * 2;
function linspace(a, b, n) {
  var out = new Array(n);
  var step = (b - a) / (n - 1 || 1);
  for (var i = 0; i < n; i++) out[i] = a + step * i;
  return out;
}
function fmt(x, d) {
  if (d === void 0) d = 4;
  return isFinite(x) ? Number(x).toFixed(d) : "∞";
}
function goldTransmission(f, amp, thickness) {
  if (f <= 0 || amp <= 0) return 0;
  return Math.exp(-thickness / (f * amp));
}
function dualityEnergy(E0, phase) {
  return phase < Math.PI / 2 ? E0 * Math.sin(phase) : E0 * Math.exp(phase);
}
function correlate(sig, ref) {
  var n = Math.min(sig.length, ref.length);
  var dot = 0, n1 = 0, n2 = 0;
  for (var i = 0; i < n; i++) { dot += sig[i] * ref[i]; n1 += sig[i] * sig[i]; n2 += ref[i] * ref[i]; }
  var den = Math.sqrt((n1 || 1e-12) * (n2 || 1e-12));
  return dot / den;
}
function rngGaussian() {
  // Box–Muller
  var u = 0, v = 0; while (u === 0) u = Math.random(); while (v === 0) v = Math.random();
  return Math.sqrt(-2 * Math.log(u)) * Math.cos(TAU * v);
}
function genResonance(opts) {
  var f0 = opts.f0, duration = opts.duration, fs = opts.fs, snrDb = opts.snrDb, coil = opts.coil, squid = opts.squid;
  var n = Math.max(16, Math.floor(duration * fs));
  var t = linspace(0, duration, n);
  var ref = t.map(function(tt){ return Math.sin(TAU * f0 * tt); });
  var snrLin = Math.pow(10, snrDb / 10);
  var amp = Math.sqrt(2 * Math.max(snrLin, 0));
  var raw = t.map(function(tt, i){ return rngGaussian() + amp * ref[i]; });
  var chain = raw.map(function(v){ return v * coil * squid; });
  return { t: t, ref: ref, chain: chain };
}

// ---------------- tiny UI primitives ----------------
function Panel(props) {
  return (
    <section style={{ background: "rgba(255,255,255,0.9)", border: "1px solid #e5e7eb", borderRadius: 16, padding: 16, boxShadow: "0 1px 6px rgba(0,0,0,0.05)" }}>
      <h2 style={{ fontSize: 18, fontWeight: 700, marginBottom: 8 }}>{props.title}</h2>
      {props.children}
    </section>
  );
}
function RowInput(props) {
  return (
    <label style={{ display: "flex", alignItems: "center", gap: 8, marginBottom: 8, fontSize: 14 }}>
      <span style={{ width: 180, color: "#52525b" }}>{props.label}</span>
      <input
        type="number"
        value={props.value}
        onChange={function(e){ props.onChange(parseFloat(e.target.value)); }}
        style={{ flex: 1, padding: "6px 10px", borderRadius: 10, border: "1px solid #d4d4d8", background: "#fff" }}
      />
    </label>
  );
}
function LinePlot(props) {
  var data = props.data || [];
  var xKey = props.xKey, yKey = props.yKey;
  var width = props.width || 520;
  var height = props.height || 180;
  var color = props.color || "#0ea5e9";
  if (!data.length) return <svg width={width} height={height} />;
  var xs = data.map(function(d){ return d[xKey]; });
  var ys = data.map(function(d){ return d[yKey]; });
  var xmin = Math.min.apply(null, xs), xmax = Math.max.apply(null, xs);
  var ymin = Math.min.apply(null, ys), ymax = Math.max.apply(null, ys);
  if (!isFinite(xmin) || !isFinite(xmax)) { xmin = 0; xmax = 1; }
  if (!isFinite(ymin) || !isFinite(ymax)) { ymin = 0; ymax = 1; }
  var padY = (ymax - ymin) * 0.05 || 1;
  var y0 = ymin - padY, y1 = ymax + padY;
  function mapX(x){ return ((x - xmin) / (xmax - xmin || 1)) * (width - 40) + 20; }
  function mapY(y){ return height - 20 - ((y - y0) / (y1 - y0 || 1)) * (height - 40); }
  var path = data.map(function(d, i){ return (i ? "L" : "M") + mapX(d[xKey]) + "," + mapY(d[yKey]); }).join(" ");
  return (
    <svg width={width} height={height} style={{ background: "#ffffff", borderRadius: 12, border: "1px solid #e5e7eb" }}>
      <rect x={0} y={0} width={width} height={height} fill="#fff" rx={12} />
      <path d={path} fill="none" stroke={color} strokeWidth={2} />
      <line x1={20} y1={height - 20} x2={width - 20} y2={height - 20} stroke="#e5e7eb" />
      <line x1={20} y1={20} x2={20} y2={height - 20} stroke="#e5e7eb" />
    </svg>
  );
}

export default function App() {
  // Mirror Law
  var _infiniteWave = useState(10), infiniteWave = _infiniteWave[0], setInfiniteWave = _infiniteWave[1];
  var _loveFreq = useState(5), loveFreq = _loveFreq[0], setLoveFreq = _loveFreq[1];
  var reflectedLove = useMemo(function(){ return infiniteWave * loveFreq; }, [infiniteWave, loveFreq]);

  // Gold Barrier
  var _gbFreq = useState(10), gbFreq = _gbFreq[0], setGbFreq = _gbFreq[1];
  var _gbAmp = useState(1), gbAmp = _gbAmp[0], setGbAmp = _gbAmp[1];
  var _gbThick = useState(0.1), gbThick = _gbThick[0], setGbThick = _gbThick[1];
  var gbSweep = useMemo(function(){ return linspace(1, 60, 200).map(function(f){ return { f: f, T: goldTransmission(f, gbAmp, gbThick) }; }); }, [gbAmp, gbThick]);
  var Tnow = useMemo(function(){ return goldTransmission(gbFreq, gbAmp, gbThick); }, [gbFreq, gbAmp, gbThick]);

  // Particle Duality
  var _E0 = useState(10), E0 = _E0[0], setE0 = _E0[1];
  var _phase = useState(Math.PI / 4), phase = _phase[0], setPhase = _phase[1];
  var dualE = useMemo(function(){ return dualityEnergy(E0, phase); }, [E0, phase]);
  var dualSweep = useMemo(function(){ return linspace(0, Math.PI, 200).map(function(p){ return { p: p, E: dualityEnergy(E0, p) }; }); }, [E0]);

  // Resonance Detection
  var _f0 = useState(10), f0 = _f0[0], setF0 = _f0[1];
  var _snrDb = useState(-3), snrDb = _snrDb[0], setSnrDb = _snrDb[1];
  var _coil = useState(0.1), coil = _coil[0], setCoil = _coil[1];
  var _squid = useState(0.01), squid = _squid[0], setSquid = _squid[1];
  var _duration = useState(2), duration = _duration[0], setDuration = _duration[1];
  var _fs = useState(1000), fs = _fs[0], setFs = _fs[1];

  var det = useMemo(function(){ return genResonance({ f0: f0, duration: duration, fs: fs, snrDb: snrDb, coil: coil, squid: squid }); }, [f0, duration, fs, snrDb, coil, squid]);
  var corr = useMemo(function(){ return correlate(det.chain, det.ref); }, [det]);
  var detected = corr > 0.02;
  var timeSeries = useMemo(function(){ return det.t.map(function(tt, i){ return { t: tt, y: det.chain[i] }; }); }, [det]);

  return (
    <div style={{ minHeight: "100vh", padding: 16, background: "linear-gradient(#fafafa, #f1f5f9)", color: "#0f172a" }}>
      <div style={{ maxWidth: 1100, margin: "0 auto", display: "grid", gap: 16 }}>
        <header style={{ display: "flex", alignItems: "center", justifyContent: "space-between" }}>
          <div>
            <h1 style={{ fontSize: 24, fontWeight: 800, margin: 0 }}>Infinity Field Lab (Ultra‑Lite)</h1>
            <p style={{ margin: 0, color: "#475569", fontSize: 12 }}>Pure React • No packages • ES5‑safe JSX</p>
          </div>
          <div style={{ fontSize: 12, opacity: 0.7 }}>Powered by Infinity</div>
        </header>

        <Panel title="Mirror Law of Infinity (Love Reflector)">
          <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 12 }}>
            <div>
              <RowInput label="Infinite Wave (Hz)" value={infiniteWave} onChange={setInfiniteWave} />
              <RowInput label="Love Frequency (Hz)" value={loveFreq} onChange={setLoveFreq} />
              <div style={{ marginTop: 6, fontSize: 14 }}>
                <strong>Reflected Love:</strong> {fmt(reflectedLove, 3)}
              </div>
              <div style={{ color: "#64748b", fontSize: 12 }}>L_ref = omega_inf × f_love</div>
            </div>
            <div style={{ fontSize: 14, lineHeight: 1.5, color: "#334155" }}>
              Coherent intention multiplies love’s carrier wave. Raising the baseline amplifies compassion without saturating boundaries.
            </div>
          </div>
        </Panel>

        <Panel title="Gold Barrier — Selective Permeability">
          <div style={{ display: "grid", gridTemplateColumns: "1fr auto", gap: 12 }}>
            <div>
              <RowInput label="Watson Frequency (Hz)" value={gbFreq} onChange={setGbFreq} />
              <RowInput label="Watson Amplitude" value={gbAmp} onChange={setGbAmp} />
              <RowInput label="Gold Thickness (mm)" value={gbThick} onChange={setGbThick} />
              <div style={{ marginTop: 6, fontSize: 14 }}>
                <strong>Transmission @ f={gbFreq}Hz:</strong> {fmt(Tnow, 4)}
              </div>
              <div style={{ color: "#64748b", fontSize: 12 }}>T = exp(-t / (f · A))</div>
            </div>
            <LinePlot data={gbSweep} xKey="f" yKey="T" />
          </div>
        </Panel>

        <Panel title="Finite ↔ Infinite Particle Duality">
          <div style={{ display: "grid", gridTemplateColumns: "1fr auto", gap: 12 }}>
            <div>
              <RowInput label="Base Energy E0" value={E0} onChange={setE0} />
              <RowInput label="Phase phi (radians)" value={phase} onChange={setPhase} />
              <div style={{ marginTop: 6, fontSize: 14 }}>
                <strong>Energy:</strong> {fmt(dualE, 4)}
              </div>
              <div style={{ color: "#64748b", fontSize: 12 }}>Finite: E = E0 · sin(phi) (phi < pi/2); Infinite: E = E0 · e^(phi)</div>
            </div>
            <LinePlot data={dualSweep} xKey="p" yKey="E" />
          </div>
        </Panel>

        <Panel title="Watson Field Resonance — Matched Filter">
          <div style={{ display: "grid", gridTemplateColumns: "1fr auto", gap: 12 }}>
            <div>
              <RowInput label="Resonance f0 (Hz)" value={f0} onChange={setF0} />
              <RowInput label="SNR (dB)" value={snrDb} onChange={setSnrDb} />
              <RowInput label="Coil Sensitivity" value={coil} onChange={setCoil} />
              <RowInput label="SQUID Sensitivity" value={squid} onChange={setSquid} />
              <RowInput label="Duration (s)" value={duration} onChange={setDuration} />
              <RowInput label="Sample Rate (Hz)" value={fs} onChange={setFs} />
              <div style={{ marginTop: 6, fontSize: 14 }}>
                <strong>Correlation:</strong> {fmt(corr, 4)}
                <span style={{ marginLeft: 8, padding: "2px 8px", borderRadius: 999, background: detected ? "#dcfce7" : "#fee2e2", color: detected ? "#166534" : "#991b1b", fontSize: 12 }}>
                  {detected ? "Detected" : "Not detected"}
                </span>
              </div>
            </div>
            <LinePlot data={timeSeries} xKey="t" yKey="y" />
          </div>
        </Panel>

        <footer style={{ textAlign: "center", fontSize: 12, color: "#64748b", paddingTop: 8 }}>
          Infinity Field Lab • Ultra‑Lite v1.3 — Rogers‑ready
        </footer>
      </div>
    </div>
  );
}

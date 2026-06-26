import { useEffect, useState, type CSSProperties } from "react";
import {
  DensityView,
  type Points,
  type DensityGrid,
  type OrbitPath,
  type Pt,
} from "./render/DensityView.js";
import { onData, onHostEvent, sendToMATLAB } from "./bridge.js";

/** Payload from the numbl script: the target density (for the heatmap) plus the
 *  WALNUTS samples. Mirrors what walnuts_sampler.m sends. */
interface WalnutsData {
  type: "walnuts";
  density: DensityGrid;
  samples: Points;
  n: number;
  dt: number;
  maxError: number;
  target: string;
}

const TARGETS: { value: string; label: string }[] = [
  { value: "banana", label: "Banana" },
  { value: "gaussian", label: "Gaussian" },
  { value: "correlated", label: "Correlated Gaussian" },
  { value: "donut", label: "Donut (ring)" },
];

function isWalnutsData(d: unknown): d is WalnutsData {
  return (
    !!d &&
    typeof d === "object" &&
    (d as WalnutsData).type === "walnuts" &&
    !!(d as WalnutsData).density &&
    !!(d as WalnutsData).samples
  );
}

interface SamplesEvent {
  x: number[];
  y: number[];
  n: number;
  dt: number;
  maxError: number;
}

/** One recorded transition's orbit (from `walnuts(..., record=true)`). */
interface MovieStep {
  px: number[];
  py: number[];
  seg: number[];
  startX: number;
  startY: number;
  selX: number;
  selY: number;
}

const SAMPLE_CHOICES = [100, 300, 1000, 3000];
const DEFAULT_N = 1000;
const DT_MIN = 0.05;
const DT_MAX = 1.2;
const ERR_MIN = 0.1;
const ERR_MAX = 4;

// Movie pacing: reveal a couple of leapfrog points per tick, then linger on the
// selected draw before the next transition.
const MOVIE_TICK_MS = 55;
const MOVIE_REVEAL = 2;
const MOVIE_HOLD = 14; // extra k-units to hold the selected point

export function App() {
  const [data, setData] = useState<WalnutsData | null>(null);
  const [n, setN] = useState(DEFAULT_N);
  const [dt, setDt] = useState(0.4);
  const [maxError, setMaxError] = useState(0.8);
  const [target, setTargetState] = useState("banana");
  const [busy, setBusy] = useState(false);
  const [movieData, setMovieData] = useState<MovieStep[] | null>(null);
  const [movie, setMovie] = useState<{ si: number; k: number } | null>(null);

  // Apply a full payload (initial Data, or a `data` event after a target change).
  const applyData = (d: WalnutsData) => {
    setData(d);
    setN(d.n);
    setDt(d.dt);
    setMaxError(d.maxError);
    setTargetState(d.target);
  };

  useEffect(() => {
    const offData = onData(d => {
      if (isWalnutsData(d)) applyData(d);
    });
    // New target: full fresh payload (density + samples).
    const offFull = onHostEvent("data", d => {
      if (isWalnutsData(d)) {
        applyData(d);
        setBusy(false);
        setMovie(null);
        setMovieData(null);
      }
    });
    // Resample: same target, new draws.
    const offSamples = onHostEvent("samples", ev => {
      const s = ev as SamplesEvent;
      if (!s || !Array.isArray(s.x)) return;
      setData(prev =>
        prev
          ? { ...prev, samples: { x: s.x, y: s.y }, n: s.n, dt: s.dt, maxError: s.maxError }
          : prev
      );
      setBusy(false);
    });
    // Movie: an array of recorded transition orbits to animate.
    const offMovie = onHostEvent("movie", ev => {
      if (!Array.isArray(ev) || ev.length === 0) {
        setBusy(false);
        return;
      }
      setMovieData(ev as MovieStep[]);
      setMovie({ si: 0, k: 0 });
      setBusy(false);
    });
    return () => {
      offData();
      offFull();
      offSamples();
      offMovie();
    };
  }, []);

  // Movie clock.
  useEffect(() => {
    if (!movie || !movieData) return;
    const id = setTimeout(() => {
      setMovie(m => {
        if (!m) return m;
        const step = movieData[m.si];
        const count = step.px.length;
        if (m.k < count + MOVIE_HOLD) return { si: m.si, k: m.k + MOVIE_REVEAL };
        const nextSi = m.si + 1;
        return nextSi >= movieData.length ? null : { si: nextSi, k: 0 };
      });
    }, MOVIE_TICK_MS);
    return () => clearTimeout(id);
  }, [movie, movieData]);

  const stopMovie = () => {
    setMovie(null);
    setMovieData(null);
  };

  const resample = (count: number, step: number, err: number) => {
    if (!data || busy) return;
    stopMovie();
    setBusy(true);
    sendToMATLAB("resample", { n: count, dt: step, maxError: err, target });
  };

  // Switch the target: the script rebuilds the density + draws and replies with
  // a full `data` event.
  const changeTarget = (value: string) => {
    setTargetState(value);
    if (!data) return;
    stopMovie();
    setBusy(true);
    sendToMATLAB("setTarget", { target: value, n, dt, maxError });
  };

  const playMovie = () => {
    if (movie) {
      stopMovie();
      return;
    }
    if (!data || busy) return;
    setBusy(true); // until the trajectory arrives
    sendToMATLAB("movie", { dt, maxError, target });
  };

  // ── derive the movie overlay for the current frame ──
  let cloud: Points = data ? data.samples : { x: [], y: [] };
  let orbit: OrbitPath | null = null;
  let start: Pt | null = null;
  let lead: Pt | null = null;
  let chainPts: Points | null = null;
  let selected: Pt | null = null;
  if (movie && movieData) {
    const step = movieData[movie.si];
    const count = step.px.length;
    const k = Math.min(movie.k, count);
    orbit = { x: step.px.slice(0, k), y: step.py.slice(0, k), seg: step.seg.slice(0, k) };
    start = { x: step.startX, y: step.startY };
    if (k > 0) lead = { x: step.px[k - 1], y: step.py[k - 1] };
    const cx: number[] = [];
    const cy: number[] = [];
    for (let j = 0; j < movie.si; j++) {
      cx.push(movieData[j].selX);
      cy.push(movieData[j].selY);
    }
    chainPts = { x: cx, y: cy };
    if (movie.k >= count) selected = { x: step.selX, y: step.selY };
    cloud = data ? data.samples : { x: [], y: [] };
  }

  const controlsDisabled = !data || busy || !!movie;
  const status = busy
    ? "sampling…"
    : movie && movieData
      ? `movie · transition ${movie.si + 1}/${movieData.length}`
      : `${data ? data.n.toLocaleString() : "—"} samples`;

  return (
    <div style={rootStyle}>
      {data ? (
        <DensityView
          density={data.density}
          samples={cloud}
          orbit={orbit}
          start={start}
          lead={lead}
          chainPts={chainPts}
          selected={selected}
        />
      ) : (
        <div style={waitingStyle}>Waiting for samples from the script…</div>
      )}

      <div style={panelStyle}>
        <div style={{ fontWeight: 600, marginBottom: 6 }}>WALNUTS</div>

        <label style={labelStyle}>
          Target
          <select
            value={target}
            disabled={controlsDisabled}
            onChange={e => changeTarget(e.target.value)}
            style={selectStyle}
          >
            {TARGETS.map(t => (
              <option key={t.value} value={t.value}>
                {t.label}
              </option>
            ))}
          </select>
        </label>

        <label style={labelStyle}>
          Samples: <b>{n.toLocaleString()}</b>
          <input
            type="range"
            min={0}
            max={SAMPLE_CHOICES.length - 1}
            step={1}
            value={Math.max(0, SAMPLE_CHOICES.indexOf(n))}
            disabled={controlsDisabled}
            onChange={e => setN(SAMPLE_CHOICES[Number(e.target.value)])}
            onPointerUp={e =>
              resample(SAMPLE_CHOICES[Number(e.currentTarget.value)], dt, maxError)
            }
            style={sliderStyle}
          />
        </label>

        <label style={labelStyle}>
          Leapfrog Δt: <b>{dt.toFixed(2)}</b>
          <input
            type="range"
            min={DT_MIN}
            max={DT_MAX}
            step={0.05}
            value={dt}
            disabled={controlsDisabled}
            onChange={e => setDt(Number(e.target.value))}
            onPointerUp={e => resample(n, Number(e.currentTarget.value), maxError)}
            style={sliderStyle}
          />
        </label>

        <label style={labelStyle}>
          Max error: <b>{maxError.toFixed(2)}</b>
          <input
            type="range"
            min={ERR_MIN}
            max={ERR_MAX}
            step={0.1}
            value={maxError}
            disabled={controlsDisabled}
            onChange={e => setMaxError(Number(e.target.value))}
            onPointerUp={e => resample(n, dt, Number(e.currentTarget.value))}
            style={sliderStyle}
          />
        </label>

        <div style={{ display: "flex", gap: 6, marginTop: 8 }}>
          <button
            style={btnStyle}
            disabled={controlsDisabled}
            onClick={() => resample(n, dt, maxError)}
            title="Draw a fresh chain with these settings"
          >
            Resample
          </button>
          <button
            style={btnStyle}
            disabled={!data || busy}
            onClick={playMovie}
            title="Animate WALNUTS building orbits step by step"
          >
            {movie ? "■ Stop" : "▶ Movie"}
          </button>
        </div>

        <div style={{ fontSize: 10, color: "#64748b", marginTop: 8 }}>
          {status}
        </div>
      </div>
    </div>
  );
}

const rootStyle: CSSProperties = {
  position: "absolute",
  inset: 0,
  overflow: "hidden",
  background: "#ffffff",
  fontFamily: "system-ui, -apple-system, Arial, sans-serif",
};

const waitingStyle: CSSProperties = {
  position: "absolute",
  inset: 0,
  display: "flex",
  alignItems: "center",
  justifyContent: "center",
  color: "#94a3b8",
};

const panelStyle: CSSProperties = {
  position: "absolute",
  top: 8,
  left: 8,
  width: 168,
  padding: "8px 10px",
  background: "rgba(255,255,255,0.92)",
  border: "1px solid #e2e8f0",
  borderRadius: 6,
  boxShadow: "0 1px 3px rgba(0,0,0,0.1)",
  color: "#0f172a",
};

const labelStyle: CSSProperties = {
  display: "block",
  fontSize: 11,
  marginTop: 6,
};

const sliderStyle: CSSProperties = {
  width: "100%",
  marginTop: 2,
};

const selectStyle: CSSProperties = {
  width: "100%",
  marginTop: 2,
  fontSize: 11,
  padding: "2px 4px",
};

const btnStyle: CSSProperties = {
  flex: 1,
  padding: "4px 6px",
  fontSize: 11,
  whiteSpace: "nowrap",
  cursor: "pointer",
  background: "#f8fafc",
  border: "1px solid #cbd5e1",
  borderRadius: 5,
  color: "#0f172a",
};

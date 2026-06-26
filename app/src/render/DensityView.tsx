import { useEffect, useRef, type CSSProperties } from "react";

export interface Points {
  x: number[];
  y: number[];
}

export interface Pt {
  x: number;
  y: number;
}

/** A recorded orbit path: positions x/y with a per-point macro-step id `seg`,
 *  so the polyline breaks where the orbit direction flips. */
export interface OrbitPath {
  x: number[];
  y: number[];
  seg: number[];
}

export interface DensityGrid {
  /** Row-major log-density: index (iy)*nx + ix, iy from ymin (0) to ymax. */
  values: number[];
  nx: number;
  ny: number;
  xmin: number;
  xmax: number;
  ymin: number;
  ymax: number;
}

interface DensityViewProps {
  density: DensityGrid;
  samples: Points;
  // ── movie overlay (all optional) ──
  orbit?: OrbitPath | null; // revealed orbit path of the current transition
  start?: Pt | null; // start point of the current transition (ringed)
  lead?: Pt | null; // current frontier point of the revealed path
  chainPts?: Points | null; // accepted draws so far (the Markov chain)
  selected?: Pt | null; // the just-selected draw (circled)
}

const DOT = "rgba(15, 23, 42, 0.5)";
const DOT_RADIUS = 1.5;
const MARGIN = 16;
// Heatmap colour ramp: white (low density) → blue (high density).
const LO: [number, number, number] = [255, 255, 255];
const HI: [number, number, number] = [37, 99, 235];
const ORBIT = "#f59e0b"; // amber: the leapfrog orbit path
const START = "#334155"; // slate ring: where the transition started
const SELECTED = "#0f172a"; // near-black: the selected draw (circled)

/** Renders the target density as a heatmap with samples scattered on top, plus
 *  an optional orbit overlay for the step-by-step movie. Fits the density's
 *  world bounds to the canvas (aspect preserved, y up). DPR-aware; redraws on
 *  data change and resize. */
export function DensityView({
  density,
  samples,
  orbit,
  start,
  lead,
  chainPts,
  selected,
}: DensityViewProps) {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const containerRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const canvas = canvasRef.current;
    const container = containerRef.current;
    if (!canvas || !container) return;

    const draw = () => {
      const ctx = canvas.getContext("2d");
      if (!ctx) return;

      const dpr = window.devicePixelRatio || 1;
      const cssW = container.clientWidth;
      const cssH = container.clientHeight;
      if (cssW === 0 || cssH === 0) return;

      canvas.width = Math.round(cssW * dpr);
      canvas.height = Math.round(cssH * dpr);
      canvas.style.width = `${cssW}px`;
      canvas.style.height = `${cssH}px`;
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      ctx.clearRect(0, 0, cssW, cssH);

      const { nx, ny, xmin, xmax, ymin, ymax, values } = density;
      if (!nx || !ny) return;

      const worldW = xmax - xmin || 1;
      const worldH = ymax - ymin || 1;
      const scale = Math.min(
        (cssW - 2 * MARGIN) / worldW,
        (cssH - 2 * MARGIN) / worldH
      );
      const destW = worldW * scale;
      const destH = worldH * scale;
      const destX = (cssW - destW) / 2;
      const destY = (cssH - destH) / 2;
      const toPx = (x: number) => destX + (x - xmin) * scale;
      const toPy = (y: number) => destY + (ymax - y) * scale; // y up

      // Heatmap: paint the grid into an offscreen nx×ny image, then scale it in.
      let maxLp = -Infinity;
      for (let i = 0; i < values.length; i++) {
        if (values[i] > maxLp) maxLp = values[i];
      }
      const off = document.createElement("canvas");
      off.width = nx;
      off.height = ny;
      const offCtx = off.getContext("2d");
      if (offCtx) {
        const img = offCtx.createImageData(nx, ny);
        for (let r = 0; r < ny; r++) {
          const iy = ny - 1 - r; // image row 0 = top = ymax
          for (let c = 0; c < nx; c++) {
            const t = Math.pow(Math.exp(values[iy * nx + c] - maxLp), 0.4);
            const p = (r * nx + c) * 4;
            img.data[p] = LO[0] + t * (HI[0] - LO[0]);
            img.data[p + 1] = LO[1] + t * (HI[1] - LO[1]);
            img.data[p + 2] = LO[2] + t * (HI[2] - LO[2]);
            img.data[p + 3] = 255;
          }
        }
        offCtx.putImageData(img, 0, 0);
        ctx.imageSmoothingEnabled = true;
        ctx.drawImage(off, destX, destY, destW, destH);
      }

      ctx.strokeStyle = "rgba(15,23,42,0.15)";
      ctx.lineWidth = 1;
      ctx.strokeRect(destX, destY, destW, destH);

      // Sample cloud (dimmed when the movie overlay is active).
      ctx.fillStyle = orbit || chainPts ? "rgba(15,23,42,0.18)" : DOT;
      const n = Math.min(samples.x.length, samples.y.length);
      for (let i = 0; i < n; i++) {
        ctx.beginPath();
        ctx.arc(toPx(samples.x[i]), toPy(samples.y[i]), DOT_RADIUS, 0, 2 * Math.PI);
        ctx.fill();
      }

      // Accepted draws so far (the Markov chain).
      if (chainPts) {
        ctx.fillStyle = SELECTED;
        const m = Math.min(chainPts.x.length, chainPts.y.length);
        for (let i = 0; i < m; i++) {
          ctx.beginPath();
          ctx.arc(toPx(chainPts.x[i]), toPy(chainPts.y[i]), 2, 0, 2 * Math.PI);
          ctx.fill();
        }
      }

      // The orbit being traced: polyline (broken at segment changes) + a dot at
      // each leapfrog step, so the discrete steps and step-size are visible.
      if (orbit && orbit.x.length > 0) {
        ctx.strokeStyle = ORBIT;
        ctx.lineWidth = 1.5;
        ctx.beginPath();
        for (let i = 0; i < orbit.x.length; i++) {
          const px = toPx(orbit.x[i]);
          const py = toPy(orbit.y[i]);
          if (i === 0 || orbit.seg[i] !== orbit.seg[i - 1]) ctx.moveTo(px, py);
          else ctx.lineTo(px, py);
        }
        ctx.stroke();
        ctx.fillStyle = ORBIT;
        for (let i = 0; i < orbit.x.length; i++) {
          ctx.beginPath();
          ctx.arc(toPx(orbit.x[i]), toPy(orbit.y[i]), 1.7, 0, 2 * Math.PI);
          ctx.fill();
        }
      }

      // Start of the current transition (open ring).
      if (start) {
        ctx.strokeStyle = START;
        ctx.lineWidth = 1.5;
        ctx.beginPath();
        ctx.arc(toPx(start.x), toPy(start.y), 4, 0, 2 * Math.PI);
        ctx.stroke();
      }

      // Current frontier of the orbit.
      if (lead) {
        ctx.fillStyle = ORBIT;
        ctx.beginPath();
        ctx.arc(toPx(lead.x), toPy(lead.y), 3, 0, 2 * Math.PI);
        ctx.fill();
      }

      // The selected draw: a circled black point.
      if (selected) {
        const cx = toPx(selected.x);
        const cy = toPy(selected.y);
        ctx.strokeStyle = SELECTED;
        ctx.lineWidth = 1.5;
        ctx.beginPath();
        ctx.arc(cx, cy, 6.5, 0, 2 * Math.PI);
        ctx.stroke();
        ctx.fillStyle = SELECTED;
        ctx.beginPath();
        ctx.arc(cx, cy, 3.2, 0, 2 * Math.PI);
        ctx.fill();
      }
    };

    draw();
    const ro = new ResizeObserver(draw);
    ro.observe(container);
    return () => ro.disconnect();
  }, [density, samples, orbit, start, lead, chainPts, selected]);

  return (
    <div ref={containerRef} style={containerStyle}>
      <canvas ref={canvasRef} style={{ display: "block" }} />
    </div>
  );
}

const containerStyle: CSSProperties = {
  position: "absolute",
  inset: 0,
  overflow: "hidden",
};

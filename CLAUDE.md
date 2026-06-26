# CLAUDE.md

Tips for future agents. Patterned after the sibling `hitandrun-interactive`
project (same numbl + uihtml two-way bridge, 2D canvas figure).

## Architecture

- `app/` — React single-file widget (`npm run build` → `app/dist/index.html`).
- `*.m` at root — `walnuts_demo.m` (driver) and `walnuts_sampler.m` (figure plumbing).
- `helpers/` — `walnuts.m` (the sampler) and the target `log_density.m` / `grad_log_density.m`, put on the path by the driver via `addpath('helpers')`.
- `numbl-project.json` — project metadata; `entry` is the landing page.

`addpath('helpers')` must be the **first statement** in the driver (numbl
resolves the search path before running, and addpath can't live inside a
function file). Run `walnuts_demo.m`, not the sampler directly.

## Data flow (uihtml bridge)

- **MATLAB → figure:** `uihtml(..., 'Data', struct)` / `sendEventToHTMLSource(src, name, data)`.
- **Figure → MATLAB:** `sendToMATLAB(name, value)` (see `app/src/bridge.ts`), received via `HTMLEventReceivedFcn`.

The script sends the density grid + samples once, then handles two requests
(`walnuts_sampler.m` `on_event`):

- `resample` `{n, dt, maxError}` → fresh chain → `samples` event. (Target is
  fixed, so the density is not re-sent.)
- `movie` `{dt, maxError}` → `walnuts(..., record=true)` for a few transitions →
  `movie` event carrying their orbit trajectories.

The figure's controls (samples / Δt / max error sliders, Resample) drive
`resample`; the **▶ Movie** button drives `movie` and animates the returned
orbits (`App.tsx` + `DensityView.tsx`).

### Trajectory recording

`walnuts.m` records the orbit path only when called with `record=true`, via
globals (`WREC_*`): `macro_step` appends each *committed* macro-step's leapfrog
path (recomputed by `leapfrog_capture`), tagged with a segment id so the figure
breaks the polyline at orbit direction flips. Plain sampling (`record=false`)
takes the fast path with no recording overhead.

## The algorithm

`helpers/walnuts.m` is a direct port of Brian Ward's `algorithms/WALNUTS.js`
from chi-feng/mcmc-demo (based on Bob Carpenter's C++,
flatironinstitute/walnuts; paper arXiv:2506.18746). Spans carry both orbit
endpoints; `macro_step` does the within-orbit step halving; `build_span`
recurses (NUTS doubling); selection is Barker within sub-orbits, Metropolis at
the top. See README for full credits.

## Performance

Unlike the hitandrun kernel, WALNUTS uses **recursion + structs**, so it runs in
the numbl **interpreter** (it does not JS-JIT like a flat numeric loop). It's
still fine — banana orbits are shallow, ~1–2 ms/transition — so keep `N` modest
(the demo uses 1000 + 200 burn-in). Don't add a `%!numbl:assert_jit` guard here;
it would (correctly) fail.

## Key files

| File | Purpose |
|------|---------|
| `app/src/App.tsx` | Reads data, hosts the info panel |
| `app/src/render/DensityView.tsx` | Canvas: density heatmap + sample scatter |
| `app/src/bridge.ts` | `onData` / `onHostEvent` / `sendToMATLAB` (generic) |
| `helpers/walnuts.m` | The WALNUTS sampler |
| `helpers/log_density.m` / `grad_log_density.m` | Banana target |
| `walnuts_sampler.m` | Runs the chain, builds the density grid, opens the figure |
| `walnuts_demo.m` | Driver: addpath + seed + call the sampler |

## Local iteration

```
cd app && npm install && npm run build      # → app/dist/index.html
cd ..
npx tsx $NUMBL/src/cli.ts run walnuts_demo.m --plot    # quick loop
# or preview the GitHub Pages bundle:
( cd $NUMBL && npm run build:site-viewer )             # one-time
npx tsx $NUMBL/src/cli.ts build-site . --out _site --base /
( cd _site && python3 -m http.server 8080 )
```

`$NUMBL` is a local clone of flatironinstitute/numbl. The real target is GitHub
Pages, where the deploy builds numbl from `main`.

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

The script sends the density grid + samples once, then handles three requests
(`walnuts_sampler.m` `on_event`):

- `resample` `{n, h, delta, target}` → fresh chain → `samples` event.
- `setTarget` `{target, …}` → new target → full `data` event (density + samples).
- `movie` `{h, delta, target}` → record a few transitions' orbits → `movie` event.

The figure's controls (target dropdown, samples / step `h` / energy-tol `δ`
sliders, Resample) drive `resample`/`setTarget`; the **▶ Movie** button drives
`movie` and animates the returned orbits (`App.tsx` + `DensityView.tsx`).

### Trajectory recording

`walnuts.m` exposes the orbit it built as a third output `O` (a cell of
`{theta, rho}` states) — purely for the movie; it doesn't affect the algorithm.
`record_movie` (in `walnuts_sampler.m`) runs a few transitions, pulls each
orbit's positions, and packs `px/py/seg` + the start and selected draw.

## The algorithm

`helpers/walnuts.m` and its building blocks (`extend_orbit_forward/backward`,
`micro`, `leapfrog`, `u_turn`/`sub_u_turn`, `p_micro`/`pmf_p_micro`) are **Nawaf
Bou-Rabee's reference MATLAB implementation**, used as provided (paper
arXiv:2506.18746). It's the orbit-based formulation: sample momentum, grow the
orbit by doubling forward/backward, refine the leapfrog step within each step so
the energy variation ≤ `δ`, terminate on a U-turn, and pick a draw from the
orbit by its `log_softmax` weights. We added only `logsumexp`/`log_softmax`
(standard helpers it calls) and a third output `O` on `walnuts` for the movie.
`walnuts` takes the density as **function handles** (`@log_density`,
`@grad_log_density`), which dispatch on the global `WTARGET` — keep the algorithm
files target-agnostic. The verbatim originals + paper are in `missing_files/`
(git-ignored).

## Performance

WALNUTS here uses **function-handle args, 2-D cell arrays, and recursion**, so it
runs in the numbl **interpreter** (it does not JS-JIT). It's still fine —
~1–5 ms/transition on these 2-D targets — but heavier than a flat loop, so keep
`N` modest (`SAMPLE_CHOICES` tops out at 3000; the demo uses 1000 + 200 burn-in).
Don't add a `%!numbl:assert_jit` guard; it would (correctly) fail.

## Key files

| File | Purpose |
|------|---------|
| `app/src/App.tsx` | Reads data, hosts the info panel |
| `app/src/render/DensityView.tsx` | Canvas: density heatmap + sample scatter |
| `app/src/bridge.ts` | `onData` / `onHostEvent` / `sendToMATLAB` (generic) |
| `helpers/walnuts.m` + building blocks | Nawaf's reference WALNUTS sampler |
| `helpers/log_density.m` / `grad_log_density.m` | 2D targets (banana/gaussian/correlated/donut), dispatched on global `WTARGET` |
| `walnuts_sampler.m` | Loops `walnuts(...)`, builds the density grid, opens the figure, handles events |
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

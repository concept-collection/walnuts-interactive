# Interactive WALNUTS sampling

Runs in the browser via [numbl](https://numbl.org) — no install.

## ▶ [Open `walnuts_demo.m`](walnuts_demo.m) and click **Run**

Samples are drawn from a 2D target by **WALNUTS** (the within-orbit adaptive
leapfrog No-U-Turn Sampler). The figure shows the target density as a heatmap
with the samples scattered on top. Switch between several targets (banana,
Gaussian, correlated Gaussian, donut) to see the sampler handle different
geometries.

WALNUTS is a NUTS variant that adapts the leapfrog step size *within* each
orbit: each macro-step halves the step (and doubles the count) until the energy
error is within tolerance, then grows the orbit by NUTS-style doubling until a
U-turn.

Controls:

- **Target** — switch the distribution (banana / Gaussian / correlated / donut).
- **Samples** / **Leapfrog Δt** / **Max error** — change a setting to re-run the
  sampler with it (lower Δt or max error → more, smaller leapfrog steps).
- **Resample** — a fresh chain with the current settings.
- **▶ Movie** — animate WALNUTS building orbits step by step: each transition
  traces its leapfrog path (amber), then circles the selected draw, which joins
  the chain and starts the next transition.

## How it works

- [`walnuts_demo.m`](walnuts_demo.m) — driver: `addpath('helpers')`, seed, call the sampler.
- [`walnuts_sampler.m`](walnuts_sampler.m) — runs the chain, evaluates the target on a grid, opens the figure.
- `helpers/` — [`walnuts.m`](helpers/walnuts.m) (the algorithm) and the target [`log_density.m`](helpers/log_density.m) / [`grad_log_density.m`](helpers/grad_log_density.m).
- `app/` — a single-file React app that draws the density heatmap + samples on a canvas.

The script sends the density grid + samples via `uihtml(..., 'Data', ...)`. The
controls call back: `resample` re-runs the chain, `setTarget` switches the
target (and rebuilds the density), and `movie` records a few transitions' orbit
trajectories (`walnuts(..., record=true)`); the script replies with
`sendEventToHTMLSource`.

## Credits

- **Algorithm:** N. Bou-Rabee, B. Carpenter, T. S. Kleppe, and S. Liu, *The
  within-orbit adaptive leapfrog no-U-turn sampler*,
  [arXiv:2506.18746](https://arxiv.org/abs/2506.18746) (2025). Reference C++ at
  [flatironinstitute/walnuts](https://github.com/flatironinstitute/walnuts)
  (Bob Carpenter).
- **This MATLAB port** follows Brian Ward's JavaScript implementation in
  [WardBrian/mcmc-demo](https://github.com/WardBrian/mcmc-demo) (`algorithms/WALNUTS.js`).
- **Demo framework & banana target** from Chi Feng's
  [mcmc-demo](https://github.com/chi-feng/mcmc-demo).

## Deploy

Pushing to `main` builds the app and publishes the project to GitHub Pages via
the [deploy workflow](.github/workflows/deploy.yml).

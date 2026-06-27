# Interactive WALNUTS sampling

Runs in the browser via [numbl](https://numbl.org) — no install.

## ▶ [Open `walnuts_demo.m`](walnuts_demo.m) and click **Run**

Samples are drawn from a 2D target by **WALNUTS** (the within-orbit adaptive
leapfrog No-U-Turn Sampler). The figure shows the target density as a heatmap
with the samples scattered on top. Switch between several targets (banana,
Gaussian, correlated Gaussian, donut) to see the sampler handle different
geometries.

WALNUTS is a NUTS variant that grows a Hamiltonian orbit by NUTS-style doubling
until a U-turn, but *within* each step it refines the leapfrog step size —
halving the step (and doubling the count) until the energy variation over the
step is within a tolerance δ — then picks a draw from the orbit.

Controls:

- **Target** — switch the distribution (banana / Gaussian / correlated / donut).
- **Samples** / **Step h** / **Energy tol δ** — change a setting to re-run the
  sampler with it (a larger base step `h` or smaller `δ` triggers more
  within-orbit refinement).
- **Resample** — a fresh chain with the current settings.
- **▶ Movie** — animate WALNUTS building orbits step by step: each transition
  traces its leapfrog path (amber), then circles the selected draw, which joins
  the chain and starts the next transition.

## How it works

- [`walnuts_demo.m`](walnuts_demo.m) — driver: `addpath('helpers')`, seed, call the sampler.
- [`walnuts_sampler.m`](walnuts_sampler.m) — loops the sampler (one transition per draw, passing the target as function handles), evaluates the target on a grid, opens the figure.
- `helpers/` — Nawaf Bou-Rabee's reference WALNUTS ([`walnuts.m`](helpers/walnuts.m) + `extend_orbit_*`, `micro`, `leapfrog`, `u_turn`/`sub_u_turn`, `p_micro`/`pmf_p_micro`), and the targets [`log_density.m`](helpers/log_density.m) / [`grad_log_density.m`](helpers/grad_log_density.m).
- `app/` — a single-file React app that draws the density heatmap + samples on a canvas.

The script sends the density grid + samples via `uihtml(..., 'Data', ...)`. The
controls call back: `resample` re-runs the chain, `setTarget` switches the
target (and rebuilds the density), and `movie` records a few transitions'
orbits; the script replies with `sendEventToHTMLSource`.

## Credits

- **Algorithm & reference MATLAB implementation:** N. Bou-Rabee, B. Carpenter,
  T. S. Kleppe, and S. Liu, *The within-orbit adaptive leapfrog no-U-turn
  sampler*, [arXiv:2506.18746](https://arxiv.org/abs/2506.18746) (2025). The
  `helpers/` sampler (`walnuts.m` + its building blocks) is Nawaf Bou-Rabee's
  reference MATLAB code, used here as provided. Reference C++ at
  [flatironinstitute/walnuts](https://github.com/flatironinstitute/walnuts).
- **Target distributions** (banana, donut, …) from Chi Feng's
  [mcmc-demo](https://github.com/chi-feng/mcmc-demo).

## Deploy

Pushing to `main` builds the app and publishes the project to GitHub Pages via
the [deploy workflow](.github/workflows/deploy.yml).

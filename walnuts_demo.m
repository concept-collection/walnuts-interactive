% WALNUTS sampling of a 2D target.
%
% WALNUTS (the within-orbit adaptive leapfrog No-U-Turn Sampler) builds a
% Hamiltonian orbit, refining the leapfrog step within the orbit so the energy
% stays accurate, and picks a draw from the orbit. This samples a 2D target
% (banana by default) and shows the density with the samples on top.
%
% The sampler is Nawaf Bou-Rabee's reference MATLAB implementation
% (helpers/walnuts.m + helpers); the target is helpers/log_density.m /
% grad_log_density.m. `addpath` must be the first statement.

addpath('helpers');     % walnuts, extend_orbit_*, micro, leapfrog, u_turn, ...

rng(1);                 % reproducible

walnuts_sampler(1000, 0.8, log(1 / 0.66));   % N samples, step h, energy tol delta

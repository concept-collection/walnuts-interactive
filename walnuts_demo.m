% WALNUTS sampling of a 2D "banana" target.
%
% WALNUTS (Within-orbit Adaptive No-U-Turn Sampler) is a NUTS variant that
% adapts the leapfrog step size within each orbit. This draws samples from the
% banana target and shows the density with the samples on top.
%
% The algorithm lives in helpers/walnuts.m; the target in helpers/log_density.m
% and helpers/grad_log_density.m. `addpath` must be the first statement.

addpath('helpers');     % walnuts, log_density, grad_log_density

rng(1);                 % reproducible

walnuts_sampler(1000, 0.4, 0.8);   % N samples, leapfrog dt, max energy error

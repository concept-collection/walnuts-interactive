function walnuts_sampler(N, h, delta, target)
%WALNUTS_SAMPLER  Interactive figure: WALNUTS sampling of a 2D target.
%   WALNUTS_SAMPLER(N, H, DELTA, TARGET) draws N samples from TARGET
%   ('banana' | 'gaussian' | 'correlated' | 'donut') with Nawaf Bou-Rabee's
%   WALNUTS sampler (helpers/walnuts.m) and opens a figure showing the density
%   and the samples. H is the base leapfrog step and DELTA the per-macro-step
%   energy-variation tolerance that drives the within-orbit step refinement.
%
%   This is the wiring: it selects the target, runs the sampler (one
%   walnuts(...) transition per draw, passing the target as function handles),
%   evaluates the target on a grid for the heatmap, loads the figure app, and
%   sends both. It also handles requests from the figure (change target,
%   resample, record an orbit movie). Run walnuts_demo.m (which addpath's
%   helpers/).

if nargin < 1 || isempty(N); N = 1000; end
if nargin < 2 || isempty(h); h = 0.8; end
if nargin < 3 || isempty(delta); delta = log(1 / 0.66); end
if nargin < 4 || isempty(target); target = 'banana'; end

set_target(target);
samples = run_chain(N, h, delta, target);
dens = density_grid(target);

html = fileread(fullfile('app', 'dist', 'index.html'));
fig = figure;
gl = uigridlayout(fig, [1 1], 'Padding', [0 0 0 0], ...
                  'RowHeight', {'1x'}, 'ColumnWidth', {'1x'});
uihtml(gl, 'HTMLSource', html, 'Data', pack_data(samples, dens, N, h, delta, target), ...
       'HTMLEventReceivedFcn', @(src, ev) on_event(src, ev));
end

function on_event(src, ev)
% Figure -> script. The figure owns the current settings and passes them back:
%   'resample'  {n, h, delta, target} -> fresh chain; reply 'samples'.
%   'setTarget' {target, ...}          -> new target; reply full 'data'.
%   'movie'     {h, delta, target}     -> record orbit trajectories; 'movie'.
d = ev.HTMLEventData;
N = 1000; h = 0.8; delta = log(1 / 0.66); target = 'banana';
if isstruct(d)
    if isfield(d, 'n'); N = max(1, round(d.n)); end
    if isfield(d, 'h'); h = d.h; end
    if isfield(d, 'delta'); delta = d.delta; end
    if isfield(d, 'target'); target = d.target; end
end
set_target(target);
switch ev.HTMLEventName
    case 'resample'
        samples = run_chain(N, h, delta, target);
        sendEventToHTMLSource(src, 'samples', ...
            struct('x', samples(1, :), 'y', samples(2, :), ...
                   'n', N, 'h', h, 'delta', delta, 'target', target));
    case 'setTarget'
        samples = run_chain(N, h, delta, target);
        dens = density_grid(target);
        sendEventToHTMLSource(src, 'data', ...
            pack_data(samples, dens, N, h, delta, target));
    case 'movie'
        traj = record_movie(h, delta, target);
        sendEventToHTMLSource(src, 'movie', traj);
end
end

function samples = run_chain(N, h, delta, target)
% Nawaf's walnuts(...) is one transition; loop it, passing our target density as
% function handles (they dispatch on the global WTARGET set by set_target).
i_max = 10;
burnin = 200;
theta = target_start(target);
samples = zeros(2, N);
total = burnin + N;
for i = 1:total
    theta = walnuts(@log_density, @grad_log_density, theta, h, i_max, delta);
    if i > burnin
        samples(:, i - burnin) = theta;
    end
end
end

function traj = record_movie(h, delta, target)
% Run a few transitions and capture each one's orbit (cell of {theta, rho})
% for the step-by-step movie: px/py are the orbit positions, seg keeps them one
% polyline, startX/Y is where the transition began, selX/Y the selected draw.
i_max = 10;
n_steps = 40;
theta = target_start(target);
traj = {};
for s = 1:n_steps
    start_pt = theta;
    [theta, ~, O] = walnuts(@log_density, @grad_log_density, theta, h, i_max, delta);
    np = size(O, 1);
    px = zeros(1, np);
    py = zeros(1, np);
    for k = 1:np
        p = O{k, 1};
        px(k) = p(1);
        py(k) = p(2);
    end
    traj{s} = struct('px', px, 'py', py, 'seg', ones(1, np), ...
                     'startX', start_pt(1), 'startY', start_pt(2), ...
                     'selX', theta(1), 'selY', theta(2));
end
end

function set_target(name)
% Select the target the density handles evaluate (a process-global so the
% sampler stays target-agnostic).
global WTARGET
WTARGET = target_code(name);
end

function c = target_code(name)
switch name
    case 'gaussian'
        c = 2;
    case 'correlated'
        c = 3;
    case 'donut'
        c = 4;
    otherwise
        c = 1;   % banana
end
end

function s = target_start(name)
% A sensible interior start for each target (the ring's hole is a bad start, so
% the donut starts on the ring).
switch name
    case 'donut'
        s = [2.5; 0];
    case 'banana'
        s = [0; 1];
    otherwise
        s = [0; 0];
end
end

function [xmin, xmax, ymin, ymax] = target_bounds(name)
switch name
    case 'banana'
        xmin = -6; xmax = 6; ymin = -7; ymax = 3;
    otherwise
        xmin = -4; xmax = 4; ymin = -4; ymax = 4;
end
end

function dens = density_grid(target)
%DENSITY_GRID  Evaluate the selected target on a grid for the heatmap.
%   Row-major flat values: index (iy-1)*nx + ix, iy from ymin (1) to ymax (ny).
[xmin, xmax, ymin, ymax] = target_bounds(target);
nx = 100; ny = 100;
xs = linspace(xmin, xmax, nx);
ys = linspace(ymin, ymax, ny);
values = zeros(1, nx * ny);
k = 1;
for iy = 1:ny
    for ix = 1:nx
        values(k) = log_density([xs(ix); ys(iy)]);
        k = k + 1;
    end
end
dens = struct('values', values, 'nx', nx, 'ny', ny, ...
              'xmin', xmin, 'xmax', xmax, 'ymin', ymin, 'ymax', ymax);
end

function data = pack_data(samples, dens, N, h, delta, target)
data = struct();
data.type = 'walnuts';
data.samples = struct('x', samples(1, :), 'y', samples(2, :));
data.density = dens;
data.n = N;
data.h = h;
data.delta = delta;
data.target = target;
end

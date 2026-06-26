function walnuts_sampler(N, dt, max_error, target)
%WALNUTS_SAMPLER  Interactive figure: WALNUTS sampling of a 2D target.
%   WALNUTS_SAMPLER(N, DT, MAX_ERROR, TARGET) draws N samples from TARGET
%   ('banana' | 'gaussian' | 'correlated' | 'donut') with the WALNUTS sampler
%   (helpers/walnuts.m) and opens a figure showing the density and the samples.
%
%   This is the wiring: it selects the target, runs the sampler, evaluates the
%   target on a grid for the heatmap, loads the prebuilt figure app, and sends
%   both. It also handles requests from the figure (figure -> script): change
%   the target, resample, or record an orbit movie. Run walnuts_demo.m (which
%   addpath's helpers/).

if nargin < 1 || isempty(N); N = 1000; end
if nargin < 2 || isempty(dt); dt = 0.4; end
if nargin < 3 || isempty(max_error); max_error = 0.8; end
if nargin < 4 || isempty(target); target = 'banana'; end

set_target(target);
samples = run_chain(N, dt, max_error, target);
dens = density_grid(target);

html = fileread(fullfile('app', 'dist', 'index.html'));
fig = figure;
gl = uigridlayout(fig, [1 1], 'Padding', [0 0 0 0], ...
                  'RowHeight', {'1x'}, 'ColumnWidth', {'1x'});
uihtml(gl, 'HTMLSource', html, 'Data', pack_data(samples, dens, N, dt, max_error, target), ...
       'HTMLEventReceivedFcn', @(src, ev) on_event(src, ev));
end

function on_event(src, ev)
% Figure -> script. The figure owns the current settings and passes them back:
%   'resample'  {n, dt, maxError, target} -> fresh chain; reply 'samples'.
%   'setTarget' {target, ...}             -> new target; reply full 'data'
%                                            (density + samples).
%   'movie'     {dt, maxError, target}    -> record orbit trajectories; 'movie'.
d = ev.HTMLEventData;
N = 1000; dt = 0.4; max_error = 0.8; target = 'banana';
if isstruct(d)
    if isfield(d, 'n'); N = max(1, round(d.n)); end
    if isfield(d, 'dt'); dt = d.dt; end
    if isfield(d, 'maxError'); max_error = d.maxError; end
    if isfield(d, 'target'); target = d.target; end
end
set_target(target);
switch ev.HTMLEventName
    case 'resample'
        samples = run_chain(N, dt, max_error, target);
        sendEventToHTMLSource(src, 'samples', ...
            struct('x', samples(1, :), 'y', samples(2, :), ...
                   'n', N, 'dt', dt, 'maxError', max_error, 'target', target));
    case 'setTarget'
        samples = run_chain(N, dt, max_error, target);
        dens = density_grid(target);
        sendEventToHTMLSource(src, 'data', ...
            pack_data(samples, dens, N, dt, max_error, target));
    case 'movie'
        n_steps = 12;
        [~, traj] = walnuts(target_start(target), n_steps, dt, max_error, true);
        sendEventToHTMLSource(src, 'movie', traj);
end
end

function set_target(name)
% Select the target the density functions evaluate (a process-global so
% walnuts.m's leapfrog can stay target-agnostic).
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
% A sensible interior starting point for each target (the ring's hole is a bad
% start, so the donut starts on the ring).
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

function samples = run_chain(N, dt, max_error, target)
burnin = 200;
chain = walnuts(target_start(target), burnin + N, dt, max_error);
samples = chain(:, burnin + 1:end);
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

function data = pack_data(samples, dens, N, dt, max_error, target)
data = struct();
data.type = 'walnuts';
data.samples = struct('x', samples(1, :), 'y', samples(2, :));
data.density = dens;
data.n = N;
data.dt = dt;
data.maxError = max_error;
data.target = target;
end

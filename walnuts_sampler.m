function walnuts_sampler(N, dt, max_error)
%WALNUTS_SAMPLER  Interactive figure: WALNUTS sampling of a 2D banana target.
%   WALNUTS_SAMPLER(N, DT, MAX_ERROR) draws N samples from the banana target
%   (helpers/log_density.m) with the WALNUTS sampler (helpers/walnuts.m) and
%   opens a figure showing the target density and the samples.
%
%   This is the wiring: it runs the sampler, evaluates the target on a grid for
%   the heatmap, loads the prebuilt figure app, and sends both to it. It also
%   re-samples on request (figure -> script), wired so adding controls later is
%   a UI-only change. Run walnuts_demo.m (which addpath's helpers/).

if nargin < 1 || isempty(N); N = 1000; end
if nargin < 2 || isempty(dt); dt = 0.4; end
if nargin < 3 || isempty(max_error); max_error = 0.8; end

burnin = 200;
chain = walnuts(randn(2, 1), burnin + N, dt, max_error);
samples = chain(:, burnin + 1:end);

dens = density_grid();

html = fileread(fullfile('app', 'dist', 'index.html'));
fig = figure;
gl = uigridlayout(fig, [1 1], 'Padding', [0 0 0 0], ...
                  'RowHeight', {'1x'}, 'ColumnWidth', {'1x'});
uihtml(gl, 'HTMLSource', html, 'Data', pack_data(samples, dens, N, dt, max_error), ...
       'HTMLEventReceivedFcn', @(src, ev) on_event(src, ev));
end

function on_event(src, ev)
% Figure -> script. The target is fixed, so the figure only ever needs new
% samples or a movie trajectory back.
%   'resample' {n, dt, maxError}  -> draw a fresh chain; reply with 'samples'.
%   'movie'    {dt, maxError}     -> record a short chain's orbit trajectories;
%                                    reply with 'movie'.
d = ev.HTMLEventData;
N = 1000; dt = 0.4; max_error = 0.8;
if isstruct(d)
    if isfield(d, 'n'); N = max(1, round(d.n)); end
    if isfield(d, 'dt'); dt = d.dt; end
    if isfield(d, 'maxError'); max_error = d.maxError; end
end
switch ev.HTMLEventName
    case 'resample'
        burnin = 200;
        chain = walnuts(randn(2, 1), burnin + N, dt, max_error);
        samples = chain(:, burnin + 1:end);
        sendEventToHTMLSource(src, 'samples', ...
            struct('x', samples(1, :), 'y', samples(2, :), 'n', N, 'dt', dt, 'maxError', max_error));
    case 'movie'
        % Record the orbit-building trajectory of a few transitions for the
        % step-by-step animation. Each traj{i} = {px, py, seg, startX/Y, selX/Y}.
        n_steps = 12;
        [~, traj] = walnuts(randn(2, 1), n_steps, dt, max_error, true);
        sendEventToHTMLSource(src, 'movie', traj);
end
end

function dens = density_grid()
%DENSITY_GRID  Evaluate the target log density on a grid for the heatmap.
%   Row-major flat values: index (iy-1)*nx + ix, iy from ymin (1) to ymax (ny).
xmin = -6; xmax = 6;
ymin = -7; ymax = 3;
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

function data = pack_data(samples, dens, N, dt, max_error)
data = struct();
data.type = 'walnuts';
data.samples = struct('x', samples(1, :), 'y', samples(2, :));
data.density = dens;
data.n = N;
data.dt = dt;
data.maxError = max_error;
end

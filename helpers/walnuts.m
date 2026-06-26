function [chain, traj] = walnuts(theta0, n_samples, dt, max_error, record)
%WALNUTS  Within-orbit adaptive No-U-Turn Sampler.
%   CHAIN = WALNUTS(THETA0, N_SAMPLES, DT, MAX_ERROR) runs N_SAMPLES WALNUTS
%   transitions starting from column vector THETA0 and returns CHAIN, a
%   dim-by-N_SAMPLES matrix of draws. DT is the base leapfrog step and MAX_ERROR
%   the per-macro-step energy-error tolerance that drives the within-orbit step
%   halving.
%
%   [CHAIN, TRAJ] = WALNUTS(..., true) additionally records, per transition, the
%   leapfrog path of the orbit it builds (for the figure's step-by-step movie).
%   TRAJ{i} has fields px/py (orbit positions), seg (per-point macro-step id, so
%   the path breaks at direction flips), startX/startY and selX/selY. Recording
%   adds overhead, so leave it off for plain sampling.
%
%   This is a direct port of Brian Ward's JavaScript implementation in
%   chi-feng/mcmc-demo (algorithms/WALNUTS.js), itself based on Bob Carpenter's
%   C++ (flatironinstitute/walnuts) for the paper arXiv:2506.18746. The target
%   density is supplied by log_density.m / grad_log_density.m on the path.
%
%   A Span carries the two orbit endpoints (backward "_bk", forward "_fw"),
%   each with position/momentum/gradient/joint-logp, plus a selected draw
%   theta_select and the log of the summed orbit weight (logp).

if nargin < 5 || isempty(record)
    record = false;
end
% Trajectory recorder (used only when record is true). macro_step appends each
% committed leapfrog path to these as it grows the orbit.
global WREC_ON WREC_X WREC_Y WREC_SEG WREC_SEGID
WREC_ON = record;

dim = numel(theta0);
chain = zeros(dim, n_samples);
traj = {};
theta = theta0;
for i = 1:n_samples
    if record
        start_pt = theta;
        WREC_X = [];
        WREC_Y = [];
        WREC_SEG = [];
        WREC_SEGID = 0;
    end
    theta = transition(theta, dt, max_error);
    chain(:, i) = theta;
    if record
        traj{i} = struct('px', WREC_X, 'py', WREC_Y, 'seg', WREC_SEG, ...
                         'startX', start_pt(1), 'startY', start_pt(2), ...
                         'selX', theta(1), 'selY', theta(2));
    end
end
WREC_ON = false;
end

function theta_select = transition(theta, dt, max_error)
% One WALNUTS transition: sample momentum, grow the orbit by repeated doubling
% in random directions until a U-turn (or a failed step / max depth), choosing
% the draw by a Metropolis update against the growing orbit.
rho = randn(numel(theta), 1);
grad = grad_log_density(theta);
logp = log_density(theta) - sum(rho.^2) / 2;
span_accum = make_leaf_span(theta, rho, grad, logp);

for depth = 0:11
    if rand < 0.5
        direction = -1;
    else
        direction = 1;
    end
    [ok, next_span] = build_span(span_accum, direction, depth, dt, max_error);
    if ~ok
        break
    end
    combined_uturn = uturn(span_accum, next_span, direction);
    % Top-level selection is a Metropolis update (use_barker = false).
    span_accum = combine(span_accum, next_span, false, direction);
    if combined_uturn
        break
    end
end
theta_select = span_accum.theta_select;
end

function [ok, span] = build_span(span_in, direction, depth, dt, max_error)
% Recursively build a balanced orbit of 2^depth macro-steps. Returns ok=false
% if any macro-step fails or a sub-orbit U-turns.
if depth == 0
    [ok, span] = build_leaf(span_in, direction, dt, max_error);
    return
end
[ok, left] = build_span(span_in, direction, depth - 1, dt, max_error);
if ~ok
    span = left;
    return
end
[ok, right] = build_span(left, direction, depth - 1, dt, max_error);
if ~ok
    span = right;
    return
end
if uturn(left, right, direction)
    ok = false;
    span = left;
    return
end
% Sub-orbit selection is a Barker update (use_barker = true).
span = combine(left, right, true, direction);
ok = true;
end

function [ok, span] = build_leaf(span_in, direction, dt, max_error)
[success, theta_next, rho_next, grad_next, logp_next] = ...
    macro_step(span_in, direction, dt, max_error);
if ~success
    ok = false;
    span = span_in;
    return
end
span = make_leaf_span(theta_next, rho_next, grad_next, logp_next);
ok = true;
end

function [success, theta_next, rho_next, grad_next, logp_next] = ...
        macro_step(span, direction, dt, max_error)
% Take one macro-step off the orbit's leading endpoint, adaptively halving the
% leapfrog step (and doubling the count) until the energy error is within
% tolerance, then check the choice is reversible.
global WREC_ON WREC_X WREC_Y WREC_SEG WREC_SEGID
if direction == 1
    theta = span.theta_fw;
    rho = span.rho_fw;
    grad = span.grad_fw;
    logp = span.logp_fw;
    step = dt;
else
    theta = span.theta_bk;
    rho = span.rho_bk;
    grad = span.grad_bk;
    logp = span.logp_bk;
    step = -dt;
end

num_steps = 1;
for halvings = 0:9
    theta_next = theta;
    rho_next = rho;
    grad_next = grad;
    [theta_next, rho_next, grad_next] = leapfrog(theta_next, rho_next, grad_next, step, num_steps);
    logp_next = log_density(theta_next) - sum(rho_next.^2) / 2;
    if abs(logp - logp_next) <= max_error
        success = reversible(step, num_steps, theta_next, rho_next, grad_next, logp_next, max_error);
        if success && WREC_ON
            % Record this committed macro-step's leapfrog path for the movie.
            path = leapfrog_capture(theta, rho, grad, step, num_steps);
            WREC_SEGID = WREC_SEGID + 1;
            WREC_X = [WREC_X, theta(1), path(1, :)];
            WREC_Y = [WREC_Y, theta(2), path(2, :)];
            WREC_SEG = [WREC_SEG, WREC_SEGID * ones(1, num_steps + 1)];
        end
        return
    end
    num_steps = num_steps * 2;
    step = step * 0.5;
end
% No step count met the tolerance.
success = false;
theta_next = theta;
rho_next = rho;
grad_next = grad;
logp_next = logp;
end

function [theta, rho, grad] = leapfrog(theta, rho, grad, step, num_steps)
half_step = 0.5 * step;
for n = 1:num_steps
    rho = rho + half_step * grad;
    theta = theta + step * rho;
    grad = grad_log_density(theta);
    rho = rho + half_step * grad;
end
end

function path = leapfrog_capture(theta, rho, grad, step, num_steps)
% Re-run a committed macro-step, returning the position after each leapfrog
% step (dim-by-num_steps). Used only while recording the movie trajectory.
half_step = 0.5 * step;
path = zeros(numel(theta), num_steps);
for n = 1:num_steps
    rho = rho + half_step * grad;
    theta = theta + step * rho;
    grad = grad_log_density(theta);
    rho = rho + half_step * grad;
    path(:, n) = theta;
end
end

function ok = reversible(step, num_steps, theta, rho, grad, logp_next, max_error)
% The adaptive step count is reversible only if no coarser (doubled-step)
% backward integration would itself have been accepted.
if num_steps == 1
    ok = true;
    return
end
ok = true;
while num_steps >= 2
    num_steps = floor(num_steps / 2);
    step = step * 2;
    if within_tolerance(step, num_steps, theta, -rho, grad, logp_next, max_error)
        ok = false;
        return
    end
end
end

function ok = within_tolerance(step, num_steps, theta, rho, grad, logp, max_error)
[theta, rho, ~] = leapfrog(theta, rho, grad, step, num_steps);
final_logp = log_density(theta) - sum(rho.^2) / 2;
ok = abs(final_logp - logp) <= max_error;
end

function u = uturn(span1, span2, direction)
if direction == 1
    span_bk = span1;
    span_fw = span2;
else
    span_bk = span2;
    span_fw = span1;
end
scaled_diff = span_fw.theta_fw - span_bk.theta_bk;
u = (dot(span_fw.rho_fw, scaled_diff) < 0) || (dot(span_bk.rho_bk, scaled_diff) < 0);
end

function span = combine(span_old, span_new, use_barker, direction)
logp_old = span_old.logp;
logp_new = span_new.logp;
logp_total = log_sum_exp(logp_old, logp_new);
if use_barker
    log_denominator = logp_total;
else
    log_denominator = logp_old;
end
update = log(rand) < (logp_new - log_denominator);
if update
    theta_select = span_new.theta_select;
else
    theta_select = span_old.theta_select;
end
if direction == 1
    span_bk = span_old;
    span_fw = span_new;
else
    span_bk = span_new;
    span_fw = span_old;
end
span = make_combined_span(span_bk, span_fw, theta_select, logp_total);
end

function r = log_sum_exp(x, y)
m = max(x, y);
r = m + log(exp(x - m) + exp(y - m));
end

function s = make_leaf_span(theta, rho, grad, logp)
s = struct('theta_bk', theta, 'rho_bk', rho, 'grad_bk', grad, 'logp_bk', logp, ...
           'theta_fw', theta, 'rho_fw', rho, 'grad_fw', grad, 'logp_fw', logp, ...
           'theta_select', theta, 'logp', logp);
end

function s = make_combined_span(span_bk, span_fw, theta_select, logp_total)
s = struct('theta_bk', span_bk.theta_bk, 'rho_bk', span_bk.rho_bk, ...
           'grad_bk', span_bk.grad_bk, 'logp_bk', span_bk.logp_bk, ...
           'theta_fw', span_fw.theta_fw, 'rho_fw', span_fw.rho_fw, ...
           'grad_fw', span_fw.grad_fw, 'logp_fw', span_fw.logp_fw, ...
           'theta_select', theta_select, 'logp', logp_total);
end

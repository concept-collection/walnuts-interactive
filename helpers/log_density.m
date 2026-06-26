function lp = log_density(theta)
%LOG_DENSITY  Unnormalized log density of the currently selected 2D target.
%   The target is chosen by the global WTARGET (1=banana, 2=gaussian,
%   3=correlated, 4=donut), set by walnuts_sampler. Defaults to the banana.
%   Normalizing constants are dropped (irrelevant for sampling and the heatmap).
global WTARGET
t = WTARGET;
if isempty(t)
    t = 1;
end
x = theta(1);
y = theta(2);
switch t
    case 2   % standard Gaussian N(0, I)
        lp = -0.5 * (x.^2 + y.^2);
    case 3   % correlated Gaussian, covariance [1 0.8; 0.8 1]
        lp = -0.5 * (x.^2 - 2 * 0.8 * x .* y + y.^2) / (1 - 0.8^2);
    case 4   % donut / ring: radius 2.5, variance 0.15 in the radial direction
        r = sqrt(x.^2 + y.^2);
        lp = -(r - 2.5).^2 / (2 * 0.15);
    otherwise   % 1: banana (correlated Gaussian under a quadratic twist)
        a = 2;
        b = 0.2;
        y1 = x / a;
        y2 = y * a + a * b * (x.^2 + a.^2);
        d1 = y1;
        d2 = y2 - 4;
        lp = -0.5 * ((4 / 3) * (d1.^2 + d2.^2) - (4 / 3) * d1 .* d2);
end
end

function g = grad_log_density(theta)
%GRAD_LOG_DENSITY  Gradient of the selected target's log density (see
%   log_density.m). Dispatches on the global WTARGET.
global WTARGET
t = WTARGET;
if isempty(t)
    t = 1;
end
x = theta(1);
y = theta(2);
switch t
    case 2   % standard Gaussian
        g = [-x; -y];
    case 3   % correlated Gaussian, precision = inv([1 0.8; 0.8 1])
        c = 1 / (1 - 0.8^2);
        g = [-c * (x - 0.8 * y); -c * (y - 0.8 * x)];
    case 4   % donut / ring
        r = sqrt(x.^2 + y.^2);
        if r < 1e-9
            g = [0; 0];
        else
            k = -(r - 2.5) / 0.15 / r;
            g = [k * x; k * y];
        end
    otherwise   % banana
        a = 2;
        b = 0.2;
        y1 = x / a;
        y2 = y * a + a * b * (x.^2 + a.^2);
        d1 = y1;
        d2 = y2 - 4;
        gy1 = -((4 / 3) * d1 - (2 / 3) * d2);
        gy2 = -(-(2 / 3) * d1 + (4 / 3) * d2);
        g = [gy1 / a + gy2 * a * b * 2 * x; gy2 * a];
end
end

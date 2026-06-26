function g = grad_log_density(theta)
%GRAD_LOG_DENSITY  Gradient of the banana log density (see log_density.m).
a = 2;
b = 0.2;
x1 = theta(1);
x2 = theta(2);
y1 = x1 / a;
y2 = x2 * a + a * b * (x1.^2 + a.^2);
d1 = y1 - 0;
d2 = y2 - 4;
% Gradient w.r.t. y of the Gaussian log density is -inv(Sigma)*d.
gy1 = -((4 / 3) * d1 - (2 / 3) * d2);
gy2 = -(-(2 / 3) * d1 + (4 / 3) * d2);
% Chain rule back through the twist y(x).
gx1 = gy1 / a + gy2 * a * b * 2 * x1;
gx2 = gy2 * a;
g = [gx1; gx2];
end

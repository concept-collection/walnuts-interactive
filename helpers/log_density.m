function lp = log_density(theta)
%LOG_DENSITY  Unnormalized log density of the "banana" target.
%   The standard banana from chi-feng's mcmc-demo: a correlated Gaussian
%   (mean [0; 4], covariance [1 0.5; 0.5 1]) pulled into a banana shape by a
%   quadratic twist. theta is a 2x1 column vector. The normalizing constant is
%   dropped (irrelevant for sampling and for the heatmap).
a = 2;
b = 0.2;
x1 = theta(1);
x2 = theta(2);
% Twist x -> y, then evaluate the Gaussian at y.
y1 = x1 / a;
y2 = x2 * a + a * b * (x1.^2 + a.^2);
d1 = y1 - 0;
d2 = y2 - 4;
% Q = d' * inv(Sigma) * d, with inv([1 .5; .5 1]) = [4/3 -2/3; -2/3 4/3].
Q = (4 / 3) * (d1.^2 + d2.^2) - (4 / 3) * d1 .* d2;
lp = -0.5 * Q;
end

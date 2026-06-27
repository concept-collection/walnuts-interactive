function s = logsumexp(x)
%LOGSUMEXP  Numerically stable log(sum(exp(x))) over all elements of x.
m = max(x(:));
if ~isfinite(m)
    s = m;   % all -Inf -> -Inf (and +Inf -> +Inf); avoids Inf-Inf = NaN
    return
end
s = m + log(sum(exp(x(:) - m)));
end

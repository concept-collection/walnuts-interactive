function s = log_softmax(x)
%LOG_SOFTMAX  x - logsumexp(x); exp(log_softmax(x)) is a probability vector.
s = x - logsumexp(x);
end

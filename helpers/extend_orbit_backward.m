function [O, logW] = extend_orbit_backward(logmu, gradlogmu, theta_a, rho_a, logw_a, h, delta, L)
    O = {};
    logW = [];
    theta = theta_a;
    rho = rho_a;
    logw = logw_a;
    
    for iter = 1:L
        ell_b = micro(logmu, gradlogmu, theta, -rho, h, delta);
        ell = p_micro(ell_b);
        [theta_1, rho_1] = leapfrog(logmu, gradlogmu, theta, -rho, h * (2^(-ell)), 2^ell);
        rho_1 = -rho_1;
        ell_f = micro(logmu, gradlogmu, theta_1, rho_1, h, delta);
        
        if pmf_p_micro(ell, ell_f) == 0
            logw = -Inf;
        else
            logw = logw + logmu(theta_1) - 0.5 * norm(rho_1)^2 - logmu(theta) + 0.5 * norm(rho)^2 + log(pmf_p_micro(ell, ell_f)) - log(pmf_p_micro(ell, ell_b));
        end
        
        theta = theta_1;
        rho = rho_1;
        O = [{theta, rho}; O];
        logW = [logw; logW];
    end
end
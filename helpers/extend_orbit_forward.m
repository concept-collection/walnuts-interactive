function [O, logW] = extend_orbit_forward(logmu, gradlogmu, theta_b, rho_b, logw_b, h, delta, L)
    O = {};
    logW = [];
    theta = theta_b;
    rho = rho_b;
    logw = logw_b;
    
    for iter = 1:L
        ell_f = micro(logmu, gradlogmu, theta, rho, h, delta);
        ell = p_micro(ell_f);
        [theta_1, rho_1] = leapfrog(logmu, gradlogmu, theta, rho, h * (2^(-ell)), 2^ell);
        ell_b = micro(logmu, gradlogmu, theta_1, -rho_1, h, delta);
        
        if pmf_p_micro(ell, ell_b) == 0
            logw = -Inf;
        else
            logw = logw + logmu(theta_1) - 0.5 * norm(rho_1)^2 - logmu(theta) + 0.5 * norm(rho)^2 + log(pmf_p_micro(ell, ell_b))- log(pmf_p_micro(ell, ell_f));
        end
        
        theta = theta_1;
        rho = rho_1;
        O = [O; {theta, rho}];
        logW = [logW; logw];
    end
end

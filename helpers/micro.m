function ell = micro(logmu, gradlogmu, theta_0, rho_0, h_0, delta)
    ell = 0;

    max_ell = 8;  % default cap

    while ell <= max_ell
        % reset initial state for this candidate ell
        theta = theta_0;
        rho   = rho_0;

        R = 2^(ell);       % number of micro-steps
        h = h_0 / R;       % micro step size

        % initial energy
        H = -logmu(theta) + 0.5 * norm(rho)^2;
        H_max = H;
        H_min = H;

        % integrate using *your* leapfrog, one step at a time
        for j = 1:R
            [theta, rho] = leapfrog(logmu, gradlogmu, theta, rho, h, 1);
            H = -logmu(theta) + 0.5 * norm(rho)^2;
            H_max = max(H_max, H);
            H_min = min(H_min, H);
        end

        % accept this ell if energy variation is small enough
        if H_max - H_min <= delta
            return;
        end

        % otherwise, refine (halve h, double R)
        ell = ell + 1;
    end
end
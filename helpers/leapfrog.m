function [theta, rho] = leapfrog(logmu, gradlogmu, theta, rho, h, ell)
    h2=h*h;
    for k = 1:ell
        g=gradlogmu(theta);
        rho_half = rho + (h / 2) * g;
        theta = theta + h * rho_half;
        g=gradlogmu(theta);
        rho = rho_half + (h / 2) * g;
    end
    % for k = 1:ell
    %     g=gradlogmu(theta);
    %     rho_half = rho + (h / 2) * g./(1+h2*abs(g));
    %     theta = theta + h * rho_half;
    %     g=gradlogmu(theta);
    %     rho = rho_half + (h / 2) * g./(1+h2*abs(g));
    % end
end

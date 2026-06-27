function result = u_turn(O)
    theta_left = O{1,1};
    rho_left = O{1,2};
    theta_right = O{end,1};
    rho_right = O{end,2};
    
    dot1 = dot(rho_right, (theta_right - theta_left));
    dot2 = dot(rho_left, (theta_right - theta_left));
    
    result = (dot1 < 0) || (dot2 < 0);
end
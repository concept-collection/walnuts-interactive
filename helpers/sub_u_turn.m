function result = sub_u_turn(O)
    if length(O) < 2
        result = false;
        return;
    end
    result = u_turn(O) || sub_u_turn(O(1:floor(end/2))) || sub_u_turn(O(floor(end/2)+1:end));
end
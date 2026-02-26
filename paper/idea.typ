
= Idea

The idea would be, that we make a dynamic model, that incorporated a concept of hysteresis to model the asset price. 

A scetch could look like this 
$       Y_t = "ND"_t + c  D_t \
        "ND"_t = b  Y_t \
        D_t = d_0 - d_1  r_t \
        i_t = i_0 + i_1  P_t \
        r_t = (1 + m)  i_t \
        "dL" = c  D_t + "SD"_t \
        "dM"_t = "dL"_t \
        "dR"_t = k "dM"_t \
        P_t = (1 + n)  a  W_t \
        W_t = W_0 - h  U_t \
        N_t = a  Y_t \
        U_t = 1 - N_t / N^f \
        "SD"_t =    \
        "AP"_t = arg min_m U (m) -   chevron.l u, "SD"_t  chevron.r + chi norm(m - "AP"_(t-1))
        $

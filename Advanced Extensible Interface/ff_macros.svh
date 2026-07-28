////////////////////////////////////////////////////////////
/////////////  REUSABLE MACROS FOR ELEGANCE !  ////////////
///////////////////////////////////////////////////////////
`define ASYNC_RESET_EN_FF(q, d, en, clk, rst_n) \
always_ff @(posedge clk or negedge rst_n) begin \
    if (!rst_n) q <= '0; \
    else  if(en)      q <= d; \
    else              q <= q; \   
end

`define ASYNC_RESET_FF(q, d, clk, rst_n) \
always_ff @(posedge clk or negedge rst_n) begin \
    if (!rst_n) q <= '0; \
    else        q <= d; \   
end

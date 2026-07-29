* The goal is to build step by step, increasing complexity and enhancing feature set with incremental steps
* Step 1 - AXI Lite slave register which deals with write of two registers treated as identical twins
* Step 2 - On top of Step 1 , adding address decoding for each register, verifying access policies (Red only / Write Only etc) and adding the READ FSM as well
* Reading material : [AMBA AXI Protocol Specification](https://www.google.com/url?sa=t&source=web&rct=j&opi=89978449&url=https://developer.arm.com/documentation/ihi0022/l/&ved=2ahUKEwjA2be8-PaVAxUwa2wGHUrCO6YQFnoECCAQAQ&usg=AOvVaw0GSX_8jEzXP98-jq5QC36F)

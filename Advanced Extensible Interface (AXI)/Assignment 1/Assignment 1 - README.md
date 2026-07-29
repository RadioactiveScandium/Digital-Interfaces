* Step 1 - AXI Lite slave register which deals with write of two registers treated as identical twins
* Step 2 - On top of Step 1 , adding address decoding for each register, verifying access policies (Red only / Write Only etc) and adding the READ FSM as well
* Step 3 - On top of Step 2, added support for Strobe based write to activate selective byte lanes
* Step 4 - On top of Step 3, added support for fault protection and decode error (check if addresses are 32-bit aligned or not ; also checking for address out of bounds) and taking the actions for write and read accordingly (blocked write, garbage reads and a DECERR back to master)

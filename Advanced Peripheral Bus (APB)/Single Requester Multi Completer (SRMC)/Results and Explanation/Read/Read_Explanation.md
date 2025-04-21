The APB read with multiple requesters is same as for single one, with below intricacies : 

1. The entire window where the signal `transfer` is asserted denotes the valid transactions
2. The original 1K-deep SRAM is now divided into two equal banks with 512 depth each - addresses range between [0, 511] and [512, 1023]
3. `PSEL` is one-hot encoded and is 'd1 when `COMPLETER0` is selected and `d2` for `COMPLETER1`
4. The first address encountered during read is `'h3ff`, which had a value of `'hBB44` stored in the address during APB write. The FSM exits the `IDLE` state and the first pair of `SETUP` and `ACCESS` FSM states (back-to-back) denotes the first valid APB read. Clearly, `PSEL` has a value of `'d2` and the data stored in the above address is available on `PRDATA1` bus at `COMPLETER1` interface
5. Same logic follows for all other addresses
6. Now, observe the `PRDATA` bus at the `REQUESTER` interface. The data available on this bus during the last cycle of any transacation is to be considered as the correct data. Since the logic is coded in combo, any change in the MSB of `PADDR` causes soem previous values to appear on the bus in other cycles of the transaction barring the last one.

It must be noted that even though the REQUESTER tries to overwrite the data `'hBB55` on top of `'hBB44` on the address `'h3FF`, it is ignored since `transfer` is deasserted during this time.

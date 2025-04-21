The APB write with multiple requesters is same as for single one, with below intricacies : 

1. The entire window where the signal `transfer` is asserted denotes the valid transactions
2. The original 1K-deep SRAM is now divided into two equal banks with 512 depth each - addresses range between [0, 511] and [512, 1023]
3. `PSEL` is one-hot encoded and is 'd1 when COMPLETER0 is selected and `d2` for COMPLETER1
4. For the addresses `'h0, 'h1 and 'h2` in the waveform, the input data casted over the `PWDATA` bus is written into the corresponding SRAM row during the last cycle the transaction, i.e., exactly one clock cycle before the Requester FSM exits the `ACCESS` state
5. Same is applicable for addresses `'h3fe and 'h3ff` , which point to rows 510 and 511 of `COMPLETER1`

It must be noted that even though the REQUESTER tries to overwrite the data `'hBB55` on top of `'hBB44` on the address `'h3FF`, it is ignored since `transfer` is deasserted during this time.
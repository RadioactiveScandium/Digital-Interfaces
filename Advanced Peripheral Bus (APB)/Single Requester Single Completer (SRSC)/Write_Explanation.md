The write transaction can be understood in following basic steps :

1. As long as the signal `transfer` stays high, the transfer is valid and any transaction when this signal is low is deemed invalid
2. Right when `transfer` signal goes high, the requester FSM goes to `SETUP` state from `IDLE`
3. By now, the `PSEL` , `PWRITE`, `PADDR` and `PWRITE` (which is 1, denoting a Write transaction) are available
4. Exactly one clock cycle later, the FSM moves to `ACCESS` state
5. In this state, `PENABLE` is asserted and the requester waits for `PREADY` to be asserted by the completer
6. Once `PREADY` is asserted, the transaction is carried out
7. On the next clock cycle, the `PENABLE` is deasserted by the requester, marking the end of transaction
8. If there is another transaction meant for the same completer, the FSM moves back to the `SETUP` state - the requester accomplishes this by keeping the PSEL asserted.

In the waveform, a successive pair of `SETUP` and `ACCESS` states denotes exactly one transaction. At first, the address `sram[0]` is written with the data `ff`, and `sram[1:3]` with `bb22, bb33 and bb44` respectively. The input data are written into each of the SRAM rows in the last cycle of the transaction, i.e., when the `PREADY` is asserted.
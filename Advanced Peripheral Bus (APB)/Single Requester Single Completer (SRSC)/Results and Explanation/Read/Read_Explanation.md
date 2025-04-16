The read transaction, similar to a write can be understood in following basic steps :

1. As long as the signal `transfer` stays high, the transfer is valid and any transaction when this signal is low is deemed invalid
2. Right when `transfer` signal goes high, the requester FSM goes to `SETUP` state from `IDLE`
3. By now, the `PSEL` , `PWDATA`, `PADDR` and `PWRITE` (which is 0, denoting a Read transaction) are available
4. Exactly one clock cycle later, the FSM moves to `ACCESS` state
5. In this state, `PENABLE` is asserted and the requester waits for `PREADY` to be asserted by the completer
6. Once `PREADY` is asserted, the transaction is carried out
7. On the next clock cycle, the `PENABLE` is deasserted by the requester, marking the end of transaction
8. If there is another transaction meant for the same completer, the FSM moves back to the `SETUP` state - the requester accomplishes this by keeping the PSEL asserted.


In the first iteration, the system first sees a value of `3` on the `PADDR` bus, indicating the row `sram[3]` is supposed to be read. Hence, the data `bb44` previously stored in the row during the Write transactions is available on the `PRDATA` bus. Pretty clearly, the data is available on the `PRDATA` bus when `PREADY` is asserted. On the next clock cycle, the `PENABLE` signal is deasserted, marking the end of a single read. The exact same logic applies to the subsequent read operations for addresses `sram[2:1]`.

Once all the transactions are exhausted, the `transfer` signal is deasserted and the requester FSM moves back to `IDLE` state.
The Problem with valid/ready

  In a standard valid/ready handshake, the sender cannot send new data until it sees the ready signal from the receiver.

  Sender -> (valid, data) -> Receiver
  Sender <- (ready) <- Receiver

  If the physical distance between the sender and receiver is long, or if there are many pipeline stages between them, it takes a long time for the ready signal to travel back. During
  this round-trip time, the sender is stalled, and the data link is idle, wasting potential bandwidth.
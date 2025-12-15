------------------------------ MODULE network ------------------------------

EXTENDS Integers, Sequences

CONSTANT Messages, Nodes

VARIABLES Network

Init ==
    /\ Network = [s \in Nodes |-> [t \in Nodes |-> << >>]]

TypeOK ==
    /\ Network \in [Nodes -> [Nodes -> Seq(Messages)]]

InvNoSelfPacket ==
    /\ \A node \in Nodes : \A i \in 1..Len(Network[node][node]) :
        /\ LET msg == Network[node][node][i] IN
            msg.type \in {"pre-prepare"}

Send(from, to, msg) ==
    Network' = [Network EXCEPT ![from][to] = Append(@, msg)]

FaultBroadcastFrom(from, mapping) == [
    to \in Nodes |-> Append(Network[from][to], mapping[to])
    ]

FaultBroadcastFromExceptSender(from, mapping, sender_entry) == [
    to \in Nodes |->
        IF from = to
            THEN sender_entry
            ELSE Append(Network[from][to], mapping[to])
    ]

Check(from, to) == Len(Network[from][to]) > 0

Recv(from, to) == Head(Network[from][to])

PopFromIf(from, to, cond) == IF cond
    THEN [Network[from] EXCEPT ![to] = Tail(@)]
    ELSE Network[from]

TailIf(seq, cond) == IF cond THEN Tail(seq) ELSE seq

Pop(from, to) ==
    Network' = [Network EXCEPT ![from] = PopFromIf(from, to, TRUE)]

(* Broadcasts a mapping from node `from`,
 * and pop message from `sender` to `from`.
 *)
FaultBroadcastExceptSenderAndPop(from, mapping, sender) ==
    IF from = sender
        THEN Network' = [Network EXCEPT
            ![from] = FaultBroadcastFromExceptSender(from, mapping, Tail(@[sender]))
            ]
        ELSE Network' = [Network EXCEPT
            ![from] = FaultBroadcastFromExceptSender(from, mapping, @[from]),
            ![sender] = PopFromIf(sender, from, TRUE)
        ]

=============================================================================

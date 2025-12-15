------------------------------ MODULE primary ------------------------------

EXTENDS Integers, FiniteSets

CONSTANTS PrimaryNodes

VARIABLES NodeState

Init == TRUE

TypeOK == TRUE

GetPrimary(node) == NodeState[node].view % Cardinality(PrimaryNodes)

GetNextPrimary(node) == (NodeState[node].view + 1) % Cardinality(PrimaryNodes)

PrimarySeq(node) ==
    IF NodeState[node].status = "idle"
        THEN NodeState[node].seq + 1
        ELSE NodeState[node].seq + 2

CanSendPreprepare(node) ==
    /\ node \in PrimaryNodes
    /\ GetPrimary(node) = node
    /\ LET nodeState == NodeState[node] IN
        /\ nodeState.status = "idle"

=============================================================================

-------------------------------- MODULE model --------------------------------

EXTENDS pbft, Sequences, FiniteSets

RuntimeConstraint ==
    /\ \A node \in Nodes :
        /\ primary!PrimarySeq(node) < MaxPrimarySeq
    /\ \A node \in Nodes :
        /\ NodeState[node].view < 2
    /\ \A from, to \in Nodes :
        LET packets == Network[from][to] IN
            \A i \in 1..Len(packets) :
                /\ packets[i].type = "view-change" => packets[i].view < 2

SymmetryNodes == Permutations(SymNodes)

TscTypeOK == tsc!TypeOK
NwTypeOK == nw!TypeOK
NwNoSelfPacket == nw!InvNoSelfPacket
MsgsTypeOK == msgs!TypeOK
PrimaryTypeOK == primary!TypeOK
SecondaryTypeOK == secondary!TypeOK

FirstCommit == [data |-> 1, view |-> 0, seq |-> 1]
SecondCommit == [data |-> 2, view |-> 0, seq |-> 2]

Path_stage2_ViewChange == ~
    /\ \E node \in Nodes :
        /\ NodeState[node].status = "view-change"
        /\ NodeState[node].commits = <<FirstCommit>>
    /\ \E node \in Nodes :
        /\ Len(NodeState[node].commits) > 0

Path_stage2_NewView == ~
    /\ \E node \in Nodes :
        /\ NodeState[node].status = "new-view"

Path_stage2_View1 == ~
    /\ NodeState[1].view = 1
    /\ NodeState[1].status = "idle"

Path_base_Prepared == ~
    /\ \E node \in Nodes : NodeState[node].cur = 1
    /\ \E node \in Nodes : NodeState[node].cur = -1
    /\ \E node \in Nodes : NodeState[node].status = "prepared"

Path_base_Committed == ~
    /\ \E node \in Nodes : NodeState[node].commits = <<FirstCommit>>
    /\ \E node \in Nodes : NodeState[node].cur = -1

Path_base_AllCommitted == ~
    /\ \A node \in Nodes : NodeState[node].commits = <<FirstCommit>>

Path_stage2_AllCommittedTwice == ~
    /\ \A node \in Nodes : NodeState[node].commits = <<FirstCommit, SecondCommit>>

=============================================================================

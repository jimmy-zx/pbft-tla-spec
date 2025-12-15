-------------------------------- MODULE pbft --------------------------------

EXTENDS Integers, Sequences, Naturals, FiniteSets, TLC, util

CONSTANTS
    (* set of the honest nodes *)
    Honest,
    (* set of the fault nodes *)
    Fault,
    (* set of the symmetric nodes, must not be primary *)
    SymNodes,
    (* set of nodes that may be primary *)
    PrimaryNodes,
    (* set of initial view numbers *)
    View0,
    (* a bad value *)
    Bad,
    (* the value f in the PBFT algorithm *)
    F,
    MaxPrimarySeq

ASSUME
    /\ Honest \cap Fault = {}
    (* primary is determined based on view % Cardinality(PrimaryNodes) *)
    /\ SymNodes \cap PrimaryNodes = {}
    /\ PrimaryNodes \subseteq Nat

VARIABLES
    (* network for normal ops *)
    Network,
    (* network for view changes *)
    ViewNetwork,
    (* mapping from nodes to states *)
    NodeState,
    (* set of the first quorum the fault nodes try to form *)
    FaultQuorum1,
    (* timestamp counter *)
    TSC

(* set of all nodes *)
Nodes == Honest \cup Fault

(* view number *)
Views == Nat

(* sequence number *)
Seqs == Nat

(* client requests *)
Data == Int \ {0}

CommitInfo == [data: Data, view: Views, seq: Seqs]

msgs == INSTANCE messages
nw == INSTANCE network WITH Messages <- msgs!Messages
view_nw == INSTANCE network WITH Messages <- msgs!Messages, Network <- ViewNetwork
primary == INSTANCE primary
secondary == INSTANCE secondary
tsc == INSTANCE tsc
view == INSTANCE view


Init ==
    /\ tsc!Init
    /\ nw!Init
    /\ view_nw!Init
    /\ primary!Init
    /\ secondary!Init
    /\ FaultQuorum1 \in SUBSET Nodes

TypeOK ==
    /\ tsc!TypeOK
    /\ nw!TypeOK
    /\ view_nw!TypeOK
    /\ msgs!TypeOK
    /\ primary!TypeOK
    /\ secondary!TypeOK

(* BEGIN normal case *)

(* An honest primary may broadcast a pre-prepare in state `idle` *)
HonestPrimarySendPreprepare(node) ==
    /\ tsc!Next
    /\ primary!CanSendPreprepare(node)
    /\ LET mapping == [to \in Nodes |-> NodeState[node].seq + 1] IN
        /\ Network' = [Network EXCEPT
            ![node] = nw!FaultBroadcastFrom(
                node,
                [to \in Nodes |-> msgs!PreprepareMsg(node, mapping[to])]
                )
            ]
        /\ NodeState' = [NodeState EXCEPT ![node] = secondary!AfterSendPreprepare(node, mapping)]
    /\ UNCHANGED <<ViewNetwork, FaultQuorum1>>

(* An honest primary may broadcast a pre-prepare from the backlog in state `new-view` *)
HonestPrimarySendBacklogPreprepare(node) ==
    /\ tsc!Next
    /\ view!CanSendBacklogPreprepare(node)
    /\ LET mapping == [to \in Nodes |-> view!GetBacklogMsg(node).data] IN
        /\ Network' = [Network EXCEPT
            ![node] = nw!FaultBroadcastFrom(
                node,
                [to \in Nodes |-> msgs!PreprepareMsg(node, mapping[to])]
                )
            ]
        /\ NodeState' = [NodeState EXCEPT ![node] = view!AfterSendBacklogPreprepare(node, mapping)]
    /\ UNCHANGED <<ViewNetwork, FaultQuorum1>>

(* A fault primary may send a different pre-prepare to each node in state `idle`.
 *
 * Notes on modeling Byzantine failure: a fault node behave as the following
 * 1. simulate a honest node
 * 2. send different messages to different nodes (stored as mapping)
 * 3. send invalid messages
 * 4. silent
 *
 * Option 3 is invalid as we assume messages can be validated, e.g., by a
 * public key cryptography and/or the protocol. Therefore, option 3 is equivalent
 * to option 4, which only excludes certain nodes outside the quorum, and
 * the excluded nodes will finally send a view-change message.
 * Hence, if an attacker wants to sabotage the system, they will choose
 * option 1 or 2.
 *
 * Option 2 is emulated by an attacker who wants to form two quorums, i.e.,
 * request x and -x. This is the weakest assumption, as if the attacker is
 * able to form k quorums, it can form 2 quorums by forming quorum
 * 0 and 1..k.
 *)
FaultPrimarySendPreprepare(node) ==
    /\ tsc!Next
    /\ node \in Fault
    /\ primary!CanSendPreprepare(node)
    /\ LET mapping == [to \in Nodes |-> IF to \in FaultQuorum1 THEN NodeState[node].seq + 1 ELSE -NodeState[node].seq - 1] IN
        /\ Network' = [Network EXCEPT
            ![node] = nw!FaultBroadcastFrom(
                node,
                [to \in Nodes |-> msgs!PreprepareMsg(node, mapping[to])]
                )
            ]
        /\ NodeState' = [NodeState EXCEPT ![node] = secondary!AfterSendPreprepare(node, mapping)]
    /\ UNCHANGED <<ViewNetwork, FaultQuorum1>>

SendPrepareCommon(from, node, msg, mapping) ==
    /\ LET nodeState == NodeState[node] IN
        /\ nw!FaultBroadcastExceptSenderAndPop(
            node,
            [to \in Nodes |-> msgs!PrepareMsg(node, nodeState, mapping[to])],
            from
            )
        /\ NodeState' = [NodeState EXCEPT ![node] = secondary!AfterSendPrepare(node, nodeState, msg, mapping)]
    /\ UNCHANGED <<ViewNetwork, FaultQuorum1>>

(* An honest node may broadcast a prepare
 * when it is in state `idle` and receives a pre-prepare. *)
HonestNodeSendPrepare(node) ==
    /\ tsc!Next
    /\ LET nodeState == NodeState[node] IN
        LET from == primary!GetPrimary(node) IN
            /\ nw!Check(from, node)
            /\ LET msg == nw!Recv(from, node) IN
                /\ secondary!CanHandlePreprepare(nodeState, msg)
                /\ IF nodeState.mapping = Bad
                    THEN
                        /\ LET mapping == [to \in Nodes |-> msg.d] IN
                            /\ SendPrepareCommon(from, node, msg, mapping)
                    ELSE SendPrepareCommon(from, node, msg, nodeState.mapping)
    /\ UNCHANGED <<ViewNetwork, FaultQuorum1>>

(* A fault node may send different prepares to different nodes
 * when it is in state `idle` and receives a pre-prepare.
 *
 * If the node is the primary, reuse the mapping generated in pre-prepare stage.
 *)
FaultNodeSendPrepare(node) ==
    /\ tsc!Next
    /\ node \in Fault
    /\ LET nodeState == NodeState[node] IN
        LET from == primary!GetPrimary(node) IN
            /\ nw!Check(from, node)
            /\ LET msg == nw!Recv(from, node) IN
                /\ secondary!CanHandlePreprepare(nodeState, msg)
                /\ IF nodeState.mapping = Bad
                    THEN
                        LET mapping == [to \in Nodes |-> IF to \in FaultQuorum1 THEN msg.seq ELSE -msg.seq] IN
                            /\ SendPrepareCommon(from, node, msg, mapping)
                    ELSE SendPrepareCommon(from, node, msg, nodeState.mapping)
    /\ UNCHANGED <<ViewNetwork, FaultQuorum1>>

(* In state prepare, an honest (and fault) node may receive a prepare
 * and add the sender to the node's counter. *)
HonestNodeHandlePrepare(node) ==
    /\ tsc!Next
    /\ LET nodeState == NodeState[node] IN
        \E from \in Nodes :
            /\ nw!Check(from, node)
            /\ LET msg == nw!Recv(from, node) IN
                /\ secondary!CanHandlePrepare(nodeState, msg)
                /\ ~secondary!HasEnoughCounter(nodeState, msg)
                /\ nw!Pop(from, node)
                /\ NodeState' = [NodeState EXCEPT ![node] = secondary!AfterHandlePrepare(nodeState, msg)]
    /\ UNCHANGED <<ViewNetwork, FaultQuorum1>>

(* In state prepare, an honest (and fault) node may receive the 2f + 1 prepare,
 * broadcasts (or fault broadcasts)  the commit message and
 * transit to prepared state.
 *
 * Both honest and fault nodes reuses the previous mapping.
 *)
HonestNodeHandleLastPrepare(node) ==
    /\ tsc!Next
    /\ LET nodeState == NodeState[node] IN
        \E from \in Nodes :
            /\ nw!Check(from, node)
            /\ LET msg == nw!Recv(from, node) IN
                /\ secondary!CanHandlePrepare(nodeState, msg)
                /\ secondary!HasEnoughCounter(nodeState, msg)
                /\ Assert(node # from, "last prepare must not come from self")
                /\ Network' = [Network EXCEPT
                    ![from] = nw!PopFromIf(from, node, TRUE),
                    ![node] = nw!FaultBroadcastFromExceptSender(
                        node,
                        [to \in Nodes |-> msgs!CommitMsg(node, nodeState, nodeState.mapping[to])],
                        Network[node][node]
                        )
                    ]
                /\ NodeState' = [NodeState EXCEPT ![node] = secondary!AfterHandlePrepareTransit(node, nodeState)]
    /\ UNCHANGED <<ViewNetwork, FaultQuorum1>>

(* In state prepared, an honest (and fault) node may receive a commit.
 * If this is the 2f + 1 commit, the node executes the request by appending
 * it to the log. Otherwise, the node adds the sender to the node's counter. *)
HonestNodeHandleCommit(node) ==
    /\ tsc!Next
    /\ LET nodeState == NodeState[node] IN
        \E from \in Nodes :
            /\ nw!Check(from, node)
            /\ LET msg == nw!Recv(from, node) IN
                /\ secondary!CanHandleCommit(nodeState, msg)
                /\ nw!Pop(from, node)
                /\ IF secondary!HasEnoughCounter(nodeState, msg)
                    THEN NodeState' = [NodeState EXCEPT ![node] = secondary!AfterHandleCommitTransit(nodeState)]
                    ELSE NodeState' = [NodeState EXCEPT ![node] = secondary!AfterHandleCommit(nodeState, msg)]
    /\ UNCHANGED <<ViewNetwork, FaultQuorum1>>

HonestNext(node) ==
    \/ HonestPrimarySendPreprepare(node)
    \/ HonestNodeSendPrepare(node)
    \/ HonestNodeHandlePrepare(node)
    \/ HonestNodeHandleLastPrepare(node)
    \/ HonestNodeHandleCommit(node)
    \/ HonestPrimarySendBacklogPreprepare(node)

FaultNext(node) ==
    \/ FaultPrimarySendPreprepare(node)
    \/ FaultNodeSendPrepare(node)

NormalNext(node) ==
    \/ HonestNext(node)
    \/ FaultNext(node)

AllNormalNext == \E node \in Nodes : NormalNext(node)

(* BEGIN view change *)

(* If the system is blocked, nodes except the new primary may propose
 * a view-change and send to the new primary. *)
HonestNodeSendViewChange(node) ==
    /\ tsc!Next
    /\ view!CanSendViewChange(node, AllNormalNext)
    /\ view_nw!Send(node, primary!GetNextPrimary(node), view!ViewChangeMsg(node))
    /\ NodeState' = [NodeState EXCEPT ![node] = view!AfterSendViewChange(node)]
    /\ UNCHANGED <<Network, FaultQuorum1>>

(* The new primary keep running before it receives 2f view-changes. *)
HonestPrimaryHandleViewChange(node) ==
    /\ tsc!Next
    /\ \E from \in Nodes:
        /\ view_nw!Check(from, node)
        /\ LET msg == view_nw!Recv(from, node) IN
            /\ view!CanHandleViewChange(node, msg)
            /\ view_nw!Pop(from, node)
            /\ ~view!HasEnoughViewChange(node, msg)
            /\ NodeState' = [NodeState EXCEPT ![node] = view!AfterHandleViewChange(node, msg)]
    /\ UNCHANGED <<Network, FaultQuorum1>>

(* If the new primary receives 2f view-changes (and implicit one from itself),
 * it executes the view change and broadcasts the new-view message. *)
HonestPrimaryHandleLastViewChange(node) ==
    /\ tsc!Next
    /\ \E from \in Nodes:
        /\ view_nw!Check(from, node)
        /\ LET msg == view_nw!Recv(from, node) IN
            /\ view!CanHandleViewChange(node, msg)
            /\ Assert(from # node, "")
            /\ view!HasEnoughViewChange(node, msg)
            /\ NodeState' = [NodeState EXCEPT ![node] = view!AfterHandleLastViewChange(node, msg)]
            /\ ViewNetwork' = [ViewNetwork EXCEPT
                    ![from] = view_nw!PopFromIf(from, node, TRUE),
                    ![node] = view_nw!FaultBroadcastFromExceptSender(
                        node,
                        [to \in Nodes |-> view!NewViewMsg(node, msg)],
                        @[node]
                        )
                ]
    /\ UNCHANGED <<Network, FaultQuorum1>>

(* If a node receives a new-view message, it will discard its current state
 * and reset according to the message. We assume fault nodes may only choose
 * to follow the protocol, as the new-view message will come with proof. *)
HonestNodeHandleNewView(node) ==
    /\ tsc!Next
    /\ \E from \in Nodes :
        /\ view_nw!Check(from, node)
        /\ LET msg == view_nw!Recv(from, node) IN
            /\ view!CanHandleNewView(msg)
            /\ view_nw!Pop(from, node)
            /\ NodeState' = [NodeState EXCEPT ![node] = view!AfterHandleNewView(node, msg)]
    /\ UNCHANGED <<Network, FaultQuorum1>>

ViewChangeNext(node) ==
    \/ HonestNodeSendViewChange(node)
    \/ HonestPrimaryHandleViewChange(node)
    \/ HonestPrimaryHandleLastViewChange(node)
    \/ HonestNodeHandleNewView(node)

AllViewChangeNext == \E node \in Nodes : ViewChangeNext(node)

NonIdleNext ==
    \/ AllNormalNext
    \/ AllViewChangeNext

(* Removes useless packages when the system stalls. *)
NetworkGC ==
    /\ tsc!Next
    /\ ~ENABLED NonIdleNext
    /\ \E from, to \in Nodes :
        \E i \in 1..Len(Network[from][to]) :
            ~msgs!IsFuture(Network[from][to][i], to)
    /\ Network' = [
        from \in Nodes |-> [
            to \in Nodes |->
                SelectSeqArg(Network[from][to], msgs!IsFuture, to)
            ]
        ]
    /\ UNCHANGED <<NodeState, ViewNetwork, FaultQuorum1>>


IdleNext ==
    \/ NetworkGC

Fairness ==
    /\ WF_<<Network, NodeState, TSC>>(\E node \in Nodes : NormalNext(node) \/ ViewChangeNext(node))
    \* /\ \A node \in Honest :
    \*     /\ WF_<<Network, NodeState, TSC>>(NonIdleNext)
    /\ WF_<<Network, NodeState, TSC>>(NetworkGC)

Next ==
    \/ NonIdleNext
    \/ IdleNext

Spec ==
  Init
  /\ [][Next]_<<Network, NodeState, TSC>>
  /\ Fairness

Prepared(data, view_, seq, node) ==
    LET nodeState == NodeState[node] IN
        IF Len(nodeState.prepares) = 0
            THEN FALSE
            ELSE \E i \in 1..Len(nodeState.prepares) :
                nodeState.prepares[i] = [data |-> data, view |-> view_, seq |-> seq]

(* BEGIN invariants *)

(* for some seq and view, no two honest nodes are prepared on different requests *)
PrepareInv ==
    \A a, b \in Honest :
        IF 0 \in {Len(NodeState[a].prepares), Len(NodeState[b].prepares)}
            THEN TRUE
            ELSE    \A i \in 1..Len(NodeState[a].prepares) :
                    \A j \in 1..Len(NodeState[b].prepares) :
                        (
                            /\ NodeState[a].prepares[i].view = NodeState[b].prepares[j].view
                            /\ NodeState[a].prepares[i].seq = NodeState[b].prepares[j].seq
                        ) => NodeState[a].prepares[i].data = NodeState[b].prepares[j].data

(* if an honest node commits a request,
 * there exists f + 1 nodes prepared on that request. *)
CommitInv ==
    \A a \in Honest :
        IF Len(NodeState[a].commits) = 0
            THEN TRUE
            ELSE
                \A i \in 1..Len(NodeState[a].commits) : LET commit == NodeState[a].commits[i] IN
                \E bs \in SUBSET Honest : Cardinality(bs) = F + 1 /\ \A b \in bs :
                    Prepared(commit.data, commit.view, commit.seq, b)

(* BEGIN properties *)

HonestNoViewChange == [] (View0 \subseteq Honest) => \A node \in Nodes : primary!GetPrimary(node) \in View0

EventualCommit ==
    \A node \in Honest \cap PrimaryNodes :
    \A req \in 1..(MaxPrimarySeq - 2) :
    (
        /\ primary!GetPrimary(node) = node
        /\ nw!Check(node, node)
        /\ nw!Recv(node, node).type = "pre-prepare"
        /\ nw!Recv(node, node).d = req
    ) ~> (
        \E i \in 1..Len(NodeState[node].commits) :
            NodeState[node].commits[i].data = req
    )

=============================================================================

----------------------------- MODULE secondary -----------------------------

EXTENDS Integers, Sequences, Naturals, FiniteSets

CONSTANTS Views, Seqs, Data, Bad, Nodes, F, Honest, View0, CommitInfo

VARIABLES NodeState

(***************************************************************************
State machine

Normal operation:
     recv pprepare              send prepare           recv prepare
idle ------------- > p-prepared ------------ > prepare ------------ > prepared

send commit          receive commit
----------- > commit -------------- > committed (idle)
 ***************************************************************************)

NodeStates == [Nodes -> [
    status : {"idle", "pidle", "prepare", "prepared", "view-change", "new-view"},
    view: Views,
    seq: Seqs,
    cur: Data \cup {Bad},
    prepares: Seq(CommitInfo),
    commits: Seq(CommitInfo),
    counter: SUBSET Nodes,
    mapping: [Nodes -> Data] \cup {Bad},
    view_counter: SUBSET Nodes,
    view_commits: Seq(CommitInfo),
    view_backlog: Seq(CommitInfo)
]]

Init ==
    /\ \E view \in View0 :
        /\ NodeState = [s \in Nodes |-> [
                status |-> "idle",
                view |-> view,
                seq |-> 0,
                cur |-> Bad,
                prepares |-> << >>,
                commits |-> << >>,
                counter |-> {},
                mapping |-> Bad,
                view_counter |-> {},
                view_commits |-> << >>,
                view_backlog |-> << >>
            ]]

TypeOK ==
    /\ NodeState \in NodeStates
    /\ \A node \in Nodes : LET nodeState == NodeState[node] IN
        /\ nodeState.cur = Bad <=> nodeState.status \in {"idle", "pidle", "view-change", "new-view"}
        /\ nodeState.mapping = Bad <=> nodeState.status \in {"idle", "view-change", "new-view"}
        /\ nodeState.cur = Bad => nodeState.counter = {}
        /\ (node \in Honest /\ nodeState.mapping # Bad) => \A a, b \in Nodes :
            nodeState.mapping[a] = nodeState.mapping[b]
        /\ Cardinality(nodeState.counter) < 2 * F + 1
        /\ Cardinality(nodeState.view_counter) < 2 * F
        /\ nodeState.view_counter = {} => nodeState.view_commits = << >>

AfterSendPreprepare(node, mapping) ==
    LET nodeState == NodeState[node] IN
        [nodeState EXCEPT !.status = "pidle", !.mapping = mapping]

CanHandlePreprepare(state, msg) ==
    /\ state.status \in {"idle", "pidle"}
    /\ msg.type = "pre-prepare"
    /\ msg.view = state.view
    /\ msg.seq = state.seq + 1

AfterSendPrepare(node, state, msg, mapping) == [state EXCEPT
    !.status = "prepare",
    !.counter = {node},
    !.cur = msg.d,
    !.mapping = mapping
]

CanHandlePrepare(state, msg) ==
    /\ state.status = "prepare"
    /\ msg.type = "prepare"
    /\ msg.view = state.view
    /\ msg.seq = state.seq + 1
    /\ msg.d = state.cur

HasEnoughCounter(state, msg) == 
    /\ Cardinality(state.counter) >= 2 * F
    /\ msg.i \notin state.counter

AfterHandlePrepare(state, msg) == [state EXCEPT !.counter = @ \cup {msg.i}]

AfterHandlePrepareTransit(node, state) == [state EXCEPT
    !.status = "prepared",
    !.counter = {node},
    !.prepares = Append(state.prepares, [data |-> state.cur, view |-> state.view, seq |-> state.seq + 1])
]

CanHandleCommit(state, msg) ==
    /\ state.status = "prepared"
    /\ msg.type = "commit"
    /\ msg.view = state.view
    /\ msg.seq = state.seq + 1
    /\ msg.d = state.cur

AfterHandleCommit(state, msg) == [state EXCEPT !.counter = @ \cup {msg.i}]

AfterHandleCommitTransit(state) == [state EXCEPT
    !.status = IF Len(state.view_backlog) = 0 THEN "idle" ELSE "new-view",
    !.counter = {},
    !.cur = Bad,
    !.seq = state.seq + 1,
    !.commits = Append(state.commits, [data |-> state.cur, view |-> state.view, seq |-> state.seq + 1]),
    !.mapping = Bad
]

=============================================================================

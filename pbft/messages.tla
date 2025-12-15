------------------------------ MODULE messages ------------------------------

EXTENDS Integers, Sequences

CONSTANTS Views, Seqs, Nodes, Bad, Data, CommitInfo

VARIABLES NodeState

(*
 * checkpoint: instead of using checkpoint with proof, we use the sequence
 * of committed messages. Checkpoints does not help reducing states, and
 * we assume nodes can only send honest view-change messages.
 *
 * outstanding: same as above. The new primary will replay the outstanding
 * pre-prepare instead of including it in new-view.
 *)
ViewChangeMessages ==
    [type : {"view-change"}, view: Views, checkpoint: Seq(CommitInfo), outstanding: Seq(CommitInfo), i: Nodes]

(*
 * checkpoint: see ViewChangeMessages
 *)
NewViewMessages ==
    [type : {"new-view"}, view: Views, checkpoint: Seq(CommitInfo)]

Messages ==
    [type : {"pre-prepare"}, view: Views, seq: Seqs, d: Data]
        \cup
    [type : {"prepare"}, view: Views, seq: Seqs, d: Data, i: Nodes]
        \cup
    [type : {"commit"}, view: Views, seq: Seqs, d: Data, i: Nodes]
        \cup
    ViewChangeMessages
        \cup
    NewViewMessages

PreprepareMsg(node, data) == [
    type |-> "pre-prepare",
    view |-> NodeState[node].view,
    seq |-> NodeState[node].seq + 1,
    d |-> data
]

PrepareMsg(node, state, data) == [
    type |-> "prepare",
    view |-> state.view,
    seq |-> state.seq + 1,
    d |-> data,
    i |-> node
]

CommitMsg(node, state, data) == [
    type |-> "commit",
    view |-> state.view,
    seq |-> state.seq + 1,
    d |-> data,
    i |-> node
]

IsUseless(msg, node) ==
    /\ ~msg.type \in {"view-change", "new-view"}
    /\ LET nodeState == NodeState[node] IN
        \/ msg.seq < nodeState.seq
        \/ msg.view < nodeState.view
        \/  /\ msg.seq = nodeState.seq + 1
            /\ msg.view = nodeState.view
            /\  \/ msg.d # nodeState.cur
                \/ msg.type = "prepare" /\ NodeState[node].status = "prepared"

IsFuture(msg, node) == ~IsUseless(msg, node)

TypeOK == TRUE


=============================================================================

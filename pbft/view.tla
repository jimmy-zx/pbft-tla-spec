------------------------------ MODULE view ------------------------------

EXTENDS Integers, FiniteSets, util

CONSTANTS PrimaryNodes, F, Bad

VARIABLES NodeState

INSTANCE primary

(***************************************************************************
State machine

View change initiation:
     send view-change                recv new-view
idle ---------------- > view-change -------------- > idle

New primary, assume only one outstanding messages,

     recv view-change            send pprepare
idle ---------------- > new-view ------------- > pidle ...
 ***************************************************************************)

CanSendViewChange(node, AllNonIdleNext) ==
    LET nodeState == NodeState[node] IN
        /\ nodeState.status # "view-change"
        /\ node # GetNextPrimary(node)
        /\
            \* \/ nodeState.status = "idle"
            \/ ~ENABLED AllNonIdleNext

ViewChangeMsg(node) ==
    LET nodeState == NodeState[node] IN
        [
            type |-> "view-change",
            view |-> nodeState.view + 1,
            checkpoint |-> nodeState.commits,
            outstanding |->
                IF nodeState.status = "prepared"
                THEN << [data |-> nodeState.cur, view |-> nodeState.view, seq |-> nodeState.seq + 1] >>
                ELSE << >>,
            i |-> node
        ]

AfterSendViewChange(node) ==
    LET nodeState == NodeState[node] IN
        [
            nodeState EXCEPT
            !.status = "view-change",
            !.cur = Bad,
            !.counter = {},
            !.mapping = Bad
        ]

CanHandleViewChange(node, msg) ==
    LET nodeState == NodeState[node] IN
        /\ msg.type = "view-change"
        /\ msg.view = nodeState.view + 1
        /\ node = GetNextPrimary(node)

HasEnoughViewChange(node, msg) ==
    LET nodeState == NodeState[node] IN
        /\ Cardinality(nodeState.view_counter) >= 2 * F - 1
        /\ msg.i \notin nodeState.view_counter

AfterHandleViewChange(node, msg) ==
    LET nodeState == NodeState[node] IN
        [nodeState EXCEPT
            !.view_counter = @ \cup {msg.i},
            !.view_commits = MaxSeq(@, msg.checkpoint),
            !.view_backlog = MaxSeq(@, msg.outstanding)
        ]

IsNotDuplicate(commit, commits) ==
    ~\E i \in 1..Len(commits) : commits[i] = commit

AfterHandleLastViewChange(node, msg) ==
    LET nodeState == NodeState[node] IN
        LET commits == MaxSeq(nodeState.commits, MaxSeq(msg.checkpoint, nodeState.view_commits)) IN
            LET backlog == SelectSeqArg(MaxSeq(msg.outstanding, nodeState.view_backlog), IsNotDuplicate, commits) IN
                [
                    view_counter |-> {},
                    view_commits |-> << >>,
                    view_backlog |-> backlog,
                    status |->
                        IF Len(backlog) = 0
                            THEN "idle"
                            ELSE "new-view",
                    prepares |-> nodeState.prepares,
                    commits |-> commits,
                    cur |-> Bad,
                    counter |-> {},
                    mapping |-> Bad,
                    view |-> msg.view,
                    seq |-> Len(commits)
                ]

NewViewMsg(node, msg) ==
    LET nodeState == AfterHandleLastViewChange(node, msg) IN
    [
        type |-> "new-view",
        view |-> nodeState.view,
        checkpoint |-> nodeState.commits
    ]

CanHandleNewView(msg) ==
    msg.type = "new-view"

AfterHandleNewView(node, msg) ==
    LET nodeState == NodeState[node] IN
    [
        status |-> "idle",
        view |-> msg.view,
        seq |-> Len(msg.checkpoint),
        cur |-> Bad,
        commits |-> msg.checkpoint,
        prepares |-> nodeState.prepares,
        counter |-> {},
        mapping |-> Bad,
        view_counter |-> {},
        view_commits |-> << >>,
        view_backlog |-> << >>
    ]

GetBacklogMsg(node) == Head(NodeState[node].view_backlog)

CanSendBacklogPreprepare(node) ==
    /\ node \in PrimaryNodes
    /\ GetPrimary(node) = node
    /\ LET nodeState == NodeState[node] IN
        /\ nodeState.status = "new-view"
        /\ Assert(Len(nodeState.view_backlog) > 0, "")
        /\ Assert(GetBacklogMsg(node).seq = nodeState.seq + 1, "")

AfterSendBacklogPreprepare(node, mapping) ==
    LET nodeState == NodeState[node] IN
        [nodeState EXCEPT
            !.status = "pidle",
            !.view_backlog = Tail(@),
            !.mapping = mapping
            ]

=============================================================================

#import "@preview/charged-ieee:0.1.4": ieee

#set page(numbering: "1")
#show: ieee.with(
  title: [Formal Verification of Practical Byzantine Fault Tolerance in TLA+],
  abstract: [This paper develops a TLA specification of the Practical Byzantine
    Fault Tolerance (PBFT) protocol and evaluates the use of explicit-state
    model checking to analyze its correctness. The specification captures the
    core protocol logic while abstracting away implementation details that are
    not essential to safety and liveness. Key invariants and liveness properties
    are checked mechanically on a minimal fault configuration. The study also
    examines the performance of model checking PBFT, showing how interleavings
    lead to rapid state explosion and motivate careful abstraction.],
  authors: (
    (name: "Jianjun Zhao", email: "jianjun.zhao@mail.utoronto.ca"),
    (name: "Kaitian Zheng", email: "kaitian.zheng@mail.utoronto.ca"),
    (name: "Shiqi Chen", email: "sqstella.chen@utoronto.ca"),
  ),
)

#show raw: set text(font: "Liberation Mono", size: 8pt)

= Introduction

Formal verification aims to provide mathematical guarantees about the
correctness of systems whose failure would be prohibitively expensive. Unlike
traditional testing, which exercises a system on a finite set of inputs and
scenarios, formal methods attempt to prove that an implementation or design
satisfies a specification for all possible executions. This level of assurance
is increasingly important in domains like blockchain infrastructures, where bugs
can lead to irrecoverable data loss, large-scale outages, or substantial
financial damage.

Blockchains and smart-contract platforms are a particularly compelling
application area for formal verification. Smart contracts and consensus
protocols are typically deployed in mostly immutable environments, are publicly
accessible to arbitrary adversarial interactions, and directly handle valuable
digital assets. Design or implementation flaws—such as reentrancy
vulnerabilities, integer overflows, or incorrect access control—have repeatedly
led to multi-million-dollar losses @chainReentrancyAttacks,
@mediumBatchOverflowMultiple. Similarly, logic errors in consensus or
cross-chain protocols may cause forks, double-spends, or permanently locked
assets. The combination of immutability, adversarial inputs, and vast state
spaces makes informal reasoning and testing alone insufficient for high
confidence in correctness.

In this work, we use the TLA+ @lamport2002specifying specification language and
its associated model checker to investigate the formal verification of
blockchain-related protocols, with a particular focus on Practical Byzantine
Fault Tolerance (PBFT) @castro1999pbft. Our main objective is to develop a TLA+
model of PBFT and to verify its key correctness properties under explicit
assumptions about failures and asynchrony. PBFT is a widely studied Byzantine
fault-tolerant consensus protocol and forms the basis of many blockchain and
permissioned-ledger systems @omniledger2018,
@kokoriskogias2016enhancingbitcoinsecurityperformance. Its complexity makes it
an ideal target for formal verification. A precise, formally checked PBFT
specification can serve both as a reference model for implementers and as a
foundation for analyzing protocol variants, optimizations, and extensions.

The remainder of this paper is organized as follows. @Background provides
background on formal verification, safety and liveness, specifications, and
TLA+. @Normal presents our TLA+ model of PBFT during normal operations, and
@ViewChange extends the model by supporting view changes. @Validation discusses
the key safety and liveness properties verified, and @Discussion discusses our
verification results and limitations. @Conclusion concludes with a summary of
our results and a discussion on future works.

= Background <Background>

== Formal Verification and High-Stakes Systems

Formal verification encompasses a family of techniques for proving that a system
satisfies a specification expressed in mathematical logic. Instead of relying on
incomplete testing or ad-hoc reasoning, formal methods operate on an abstract
model of the system and use proof systems or automated tools (such as model
checkers and theorem provers) to explore all behaviors within a given state
space.

These methods are particularly valuable when failures are rare but catastrophic.
In hardware, a single design flaw may ship in millions of devices and be
difficult or impossible to patch. In distributed infrastructures, rare race
conditions or unexpected interleavings can trigger global outages or data
corruption @Newcombe2015amazon. In blockchains, a single vulnerability may
irreversibly drain funds from a contract. In such high-stakes settings, the
marginal cost of applying formal verification is often outweighed by the risk of
an undetected bug.

== Specifications and the Role of Abstraction

Conventional design artifacts—such as informal documents, pseudocode,
diagrams—are crucial for human communication but often underspecified,
especially around corner cases, failures, retries, and timing. Different
engineers may interpret the same pseudocode differently, leading to mismatched
expectations and subtle design flaws.

At the other extreme, production implementations are extremely detailed. They
interleave core protocol logic with logging, metrics, error handling,
configuration, and language-specific constructs. This level of detail obscures
the underlying algorithm and makes exhaustive reasoning about all possible
interleavings intractable.

Formal specification languages address this gap by providing an abstract but
precise description of system behavior. The goal is to capture the essential
state variables and transitions while ignoring engineering details that are
irrelevant for correctness.

== TLA+ and Model Checking

TLA+ (Temporal Logic of Actions @lamport2002specifying) uses the following to
specify a system:
1. State variables, representing the abstract state of the system;
2. Initial conditions, describing the set of allowed starting states; and
3. Actions, describing how states can evolve via transitions.

State transitions are expressed as logical formulas relating current-state
variables to their next-state counterparts, denoted by a prime symbol. This
notation makes it natural to describe protocols as state machines and to reason
about their temporal properties. For example, an increment statement in common
programming languages `x = x + 1` can specified by $x' = x + 1$.

// TODO: insert diagram here

Given a TLA+ specification, its model checking tools TLC can explore the
reachable state space by systematically applying actions in all possible orders.
This exhaustive exploration is especially powerful in distributed settings,
where interleavings and failure scenarios are challenging to enumerate manually.
TLC can automatically check invariants (safety properties) and temporal formulas
(liveness properties). When a property is violated, the tool produces a
counterexample trace: a finite or infinite sequence of states that shows exactly
how the violation occurs.

TLA+ has been used extensively in academia to reason about concurrent
algorithms, replicated data structures, and consensus protocols such as Paxos
and Raft @lamport2020byzpaxos; and in industry—for example, in the design of
large-scale storage systems and databases—to validate protocol designs before
implementation @Newcombe2015amazon, @mediumEliminatingSmart,
@mediumEliminatingSmart, @ahelwerTLAMore. In the
context of this project, TLA+ offers a natural framework for specifying
blockchain consensus protocols and smart contracts, and for checking their
properties against an adversarial environment.

== PBFT and the Need for a Verified Specification

Practical Byzantine Fault Tolerance (PBFT) is a seminal Byzantine fault-tolerant
state machine replication protocol that demonstrates how to build highly
available services in the presence of arbitrary (Byzantine) failures, as long as
at most $f$ out of $n >= 3f + 1$ replicas are faulty.

Introduced by Castro and Liskov, PBFT provides a concrete algorithm and
implementation techniques that achieve thousands of client requests per second
with modest latency overhead, making Byzantine fault tolerance "practical" for
real systems rather than merely a theoretical possibility @castro1999pbft.
At a high level, PBFT organizes execution into views with a
designated primary replica, and each request passes through a three-phase
agreement protocol (pre-prepare, prepare, commit) to ensure that all non-faulty
replicas execute the same sequence of operations.

The impact of PBFT extends beyond its original replicated-service setting.
Variants and optimizations of PBFT have been widely adopted in permissioned and
consortium blockchain platforms, where the consensus mechanism is responsible
for ordering transactions and providing finality. In these environments, PBFT's
safety guarantees and relatively low latency are attractive, but its quadratic
communication complexity and static membership assumptions have motivated a
large body of work on grouped, layered, and trust-based extensions tailored to
blockchain and other high-throughput distributed systems
@kogias2016 @moniz2020 @qin2023.
As these systems increasingly underpin financial,
healthcare, and critical infrastructure applications, the cost of subtle design
or implementation errors in the consensus layer becomes correspondingly higher.

= Normal Case System Model <Normal>

This section presents the structure of our TLA+ specification of PBFT and
outlines the modeling decisions that underlie it. We decompose the protocol into
a collection of interacting modules that reflect its conceptual components: the
network (`network.tla` @network.tla), the replicas including primary
(`primary.tla` @primary.tla) and secondary (`secondary.tla` @secondary.tla), the
view-change mechanism (`view.tla` @view.tla), and the global system that
composes these parts (`pbft.tla`, @pbft.tla). This modular organization serves
two purposes. First, it mirrors the way PBFT is typically described in the
literature, making the specification easier to relate to the informal algorithm.
Second, it allows individual aspects of the protocol—such as message delivery
assumptions or replica behavior—to be varied or refined without restructuring
the entire model.

At a high level, the specification defines the abstract state of the system in
terms of replica-local variables (e.g., current view, log of protocol messages,
and commit state), network state capturing in-flight messages, and global
parameters such as the number of replicas and the fault bound. The initial
conditions describe a well-formed starting configuration with a designated
primary for the initial view, empty message logs, and no pending client
requests. The next-state relation is given by a disjunction of actions
corresponding to protocol steps, including message sending and reception, local
state transitions at replicas, and view-change-related actions.

In the remainder of this section, we explain how each of these components is
modeled in TLA+.

== Network

The network (specified in @network.tla) is represented as a peer-to-peer message
buffer, where each ordered pair of replicas is associated with a FIFO queue of
in-flight messages. Conceptually, this corresponds to a point-to-point
authenticated channel between every pair of replicas. Formally, the network
state is a mapping from sender–receiver pairs to sequences of messages:
$
  "Network" in ["Nodes" -> ["Nodes" -> "Seq"("Messages")]]
$
where `Network[A][B]` is a sequence of messages currently in flight from A to B.
Sending a message can then be modelled as a state transition
`Send(from, to, msg)` that appends to the tail of that queue; while receiving a
message removes it from the head.

This FIFO discipline ensures that messages between any fixed pair of replicas
are delivered in the order they were sent, while still allowing arbitrary
interleavings across different pairs. This choice of network model is
deliberate. By modeling the network as asynchronous FIFO channels, we preserve
the essential nondeterminism of an asynchronous system—messages may be delayed
arbitrarily, and replicas may progress at different speeds—while keeping the
state space manageable for model checking.

In later sections, we discuss how this network abstraction can be relaxed to
model more adversarial conditions, such as message reordering, duplication, or
loss, by weakening the FIFO constraint or allowing additional network actions.

== Messages

The core message types (specified in @messages.tla) correspond directly to the
three-phase agreement protocol of PBFT: pre-prepare, prepare, and commit.

These messages are represented uniformly, with a message-type tag distinguishing
their roles in the protocol, a sequence number identifying a position in the
replicated log in a given view number, the id of the sender, and the request
sent by the client.

#rect(
  fill: rgb("F2F2F2"),
  figure(
    [
      ```tla
      [type : {"prepare"}, view: Views, seq: Seqs, d: Data, i: Nodes] ⊆ Messages
      ```
    ],
    caption: [
      An example TLA+ code snippet for message of type _prepare_. `view` is the
      view number; `seq` is the sequence number; `i` is the id of the replica
      that sends this message; `d` is the request sent by the client.
    ],
  ),
)

A notable modeling decision is that we omit the digest field that appears in the
original PBFT protocol. In practice, digests are used to cryptographically
verify if a message is actually sent by an authenticated sender. For the
purposes of formal verification at the protocol level, however, these
cryptographic details do not affect the control flow or the quorum logic of
PBFT, provided that messages are authenticated and cannot be forged by Byzantine
replicas.

There are also message types related to view changes. We defer a detailed
discussion of their semantics and handling to a later subsection @ViewChange
devoted specifically to view changes.

== Replica Local State <NodeState>

The global variable `NodeState` (specified in @secondary.tla) is the central
carrier of replica-local state. It is modeled as a total function from Nodes
(the union of `Honest` and `Fault`) to a structured record defined in
`secondary.tla`. Each replica record contains both control-state and the
predicate required to decide whether a replica may advance to the next PBFT
phase.

Each secondary replica maintains a `status` field drawn from a finite set of
protocol modes (e.g., "idle", "prepare", "prepared", along with several
view-change-related modes).

#rect(
  fill: rgb("F2F2F2"),
  figure(
    [
      ```tla
      status ∈ {"idle", "pidle", "prepare", "prepared", "view-change", "new-view"}
      ```
    ],
    caption: [TLA+ code that defines the type of `status`.],
  ),
)

The status field explicitly encodes PBFT's phase progression. The normal-case
skeleton is:
$
  "idle" stretch(->)^"recv pre-prepare / send prepare" "prepare" \
  stretch(->)^("recv" 2f+1 "prepares") "prepared" stretch(->)^("recv" 2f+1 "commits") "idle"
$
We also introduce "pidle" status for the primary after it sends a _pre-prepare_;
this allows the primary to "receive" its own _pre-prepare_ message (modeled as a
self-send in the network) using the same rules as other replicas, without a
special-case transition. In addition, we made a simplifying assumption that
primaries will not process a new client request until the current request is
committed. Therefore, there is at most one request being processed.

Alongside status, each replica stores its current `view` number, a local `seq`
representing sequence number for the request position being processed, and a
`cur` value representing the currently proposed request payload (or `Bad` when
no request is active). The record also includes protocol bookkeeping needed for
quorum formation and commitment, including a `counter` set used to track which
replicas have contributed matching votes for the current phase, and a commits
sequence that acts as an abstract log of committed decisions.

Primary and secondary (backup) roles are modeled by separating role selection
from role-local behavior. We do not introduce a separate `PrimaryState`
variable. Instead, "who is primary" is a derived predicate of the current view,
defined in `primary.tla`. The predicate `GetPrimary(node)` computes the
designated primary as a deterministic function of the current view.

#rect(
  fill: rgb("F2F2F2"),
  figure(
    [
      ```tla
      GetPrimary(node) == NodeState[node].view % Cardinality(PrimaryNodes)
      ```],
    caption: [TLA+ code that defines the `GetPrimary(node)` predicate where the
      parameter `node` is the id of the node. `NodeState[node].view` fetches the
      `NodeState` record associated with `node` and access the `view` field. The
      symbol `%` represents the modular arithmetic operation. `PrimaryNodes` is
      a subset of nodes that can become primary. `Cardinality` computes the
      Cardinality of that set.],
  ),
)

In effect, the model rotates the primary across a fixed subset of nodes using
modular arithmetic on the view number. Whether a node is currently allowed to
act as primary is expressed by the predicate `CanSendPreprepare(node)`, which
requires (i) the node is in `PrimaryNodes`, (ii) it is the selected primary for
its current view, and (iii) its local status is "idle".

== Honest Behavior

Replica behavior for the normal-case protocol is then written as a collection of
guarded actions in `pbft.tla` (@pbft.tla), each of which reads `NodeState`,
consults network state, and produces a next-state update. For example, the
primary's "proposal" step is captured by `HonestPrimarySendPreprepare(node)`,
which is enabled precisely when the predicate `primary!CanSendPreprepare(node)`
holds, and which broadcasts a pre-prepare message into the network and updates
the sender's local state. Note TLA+ uses `!` symbol to import
predicates/variables defined in other modules. Here `primary!CanSendPreprepare`
uses the `CanSendPreprepare` predicate defined in `primary.tla` module.

Secondary node behavior is driven by receive-and-handle steps such as
`HonestNodeSendPrepare(node)` and the subsequent handlers for prepares and
commits. These actions rely on phase-specific predicates in `secondary.tla`—for
example, `secondary!CanHandlePreprepare(state, msg)` requires that the replica
is in an idle status, that the incoming message is a _pre-prepare_ for the
replica's current view, and that it proposes the next sequence number
(`msg.seq = state.seq + 1`). Analogous predicates (`CanHandlePrepare`,
`CanHandleCommit`) encode when the replica may record additional votes and when
it may transition to the next phase correspondingly.

Honest behavior is modeled compositionally as a predicate over enabled actions.
In `pbft.tla`, the definition `HonestNext(node)` is a disjunction of the
normal-operation steps available to an honest replica (primary proposal, prepare
send, prepare/commit handling).

#rect(
  fill: rgb("F2F2F2"),
  figure(
    [
      ```tla
      HonestNext(node) ≜ ∃ node ∈ Nodes:
          ∨ HonestPrimarySendPreprepare(node)
          ∨ HonestNodeSendPrepare(node)
          ∨ HonestNodeHandlePrepare(node)
          ∨ HonestNodeHandleLastPrepare(node)
          ∨ HonestNodeHandleCommit(node)
          ∨ HonestPrimarySendBacklogPreprepare(node)
      ```
    ],
    caption: [The honest behavior is defined as a disjunction of allowed state
      transitions to an honest replica.],
  ),
)


This "behavior-as-disjunction" pattern is idiomatic in TLA+: each disjunct
corresponds to one atomic step the model checker may choose, and enabledness is
entirely determined by the action's guards (e.g., `primary!CanSendPreprepare`).

For this subsection, the key point is that honest replicas are constrained to
follow the protocol by construction: the only transitions available to an honest
node are those in `HonestNext`, and each such transition is gated by explicit
predicates that encode PBFT's phase conditions and quorum progression.

== Byzantine Behavior

We model Byzantine behavior (specified in @pbft.tla) by explicitly partitioning
replicas into two disjoint sets, `Honest` and `Fault`, and by giving replicas in
`Fault` a separate transition relation. Concretely, the top-level step relation
in `pbft.tla` is structured as a disjunction: an honest node may take one of the
actions in `HonestNext(node)`, while a faulty node may take one of the actions
in `FaultNext(node)`.

#rect(
  fill: rgb("F2F2F2"),
  figure(
    [
      ```tla
      NormalNext(node) ==
          ∨ HonestNext(node)
          ∨ FaultNext(node)
      ```
    ],
    caption: [The state transition that allows honest node to take an honest
      update and a faulty node to take a faulty update.],
  ),
)

This makes the fault model extensional: Byzantine behavior is not "inferred"
from violated invariants, but rather is encoded as the set of additional (or
weakened) actions available to faulty replicas.

In the normal-case protocol, we use a conservative but targeted adversary model:
faulty replicas are allowed to equivocate, i.e., send different protocol
messages to different recipients while still staying within the message types
and coarse phase structure of PBFT. This is sufficient to exercise the core
safety mechanisms (quorums and intersection arguments) without exploding the
state space by allowing fully arbitrary message fabrication at every step.

This is expressed through a `mapping: [Nodes → Data]` field stored in
`NodeState` mentioned above in @NodeState. `[Nodes → Data]` defines a function
that maps a node in `Nodes` to some data. When node A sends a message to node B,
it uses `NodeState[A].mapping[B]` to decide what data to be sent.

For honest nodes, the mapping is effectively constant: when broadcasting, every
recipient sees the same data. For faulty nodes, the model allows a mapping that
varies per recipient, chosen nondeterministically from a small set of
alternatives.

A node in `Fault` that is currently eligible to act as primary (i.e., it
satisfies `primary!CanSendPreprepare(node)`) can send inconsistent pre-prepare
messages to different recipients via `FaultPrimarySendPreprepare(node)`. Instead
of broadcasting a single message to all nodes, the faulty primary
nondeterministically chooses a per-recipient mapping and then broadcasts
per-recipient messages accordingly.

#rect(
  fill: rgb("F2F2F2"),
  figure(
    [
      ```tla
      mapping ∈ [Nodes → { data1, data2 }]
      ```
    ],
    caption: [TLA+ code that nondeterministically creates a mapping s.t.
      `mapping[SomeNodes] = data1` and `mapping[OtherNodes] = data2` where
      `SomeNodes ∪ OtherNodes = Nodes`.
    ],
  ),
)

The use of a two-valued choice is a trick to represent "conflicting requests"
without introducing a large state-space. It is enough to force the model to
consider executions in which two sets of honest backups accept different
proposals.

Similarly, a faulty non-primary replica can also equivocate when sending prepare
messages using predicate `FaultNodeSendPrepare(node)`.

This design has a practical verification motivation. PBFT's safety argument
hinges on quorum intersection: two conflicting values should not both become
prepared by honest replicas if fewer than $f$ replicas are Byzantine. A model
where the adversary can only equivocate between two clearly distinguishable
values is sufficient to stress that intersection argument; if the model checker
finds a violation, it is much easier to interpret than if the adversary could
generate arbitrary symbolic payloads.

= System Model with View Change <ViewChange>

The view-change logic in `view.tla` (@view.tla) is designed to be compatible
with the above normal-case machine while keeping state finite. PBFT's full
view-change protocol includes checkpoint certificates and proofs; in this model,
we represent checkpoints as the sequence of committed operations
(`commits: Seq(CommitInfo)`).

When a node decides to trigger a view change, it sends a view-change message to
the next primary. Instead of modeling explicit timers, we use an enabling-based
approximation: `CanSendViewChange(node, AllNormalNext)` permits a view change
when the system is unable to make progress via any normal-case action using the
following statement:

#rect(
  fill: rgb("F2F2F2"),
  figure(
    [
      ```tla
      ~ENABLED NormalNext
      ```
    ],
    caption: [`NormalNext` represents any valid normal-case protocol step as we
      discussed in @NodeState. The keyword `ENABLED` asserts that there exists
      at least one such step that could occur from the current state. The `~`
      symbol negates the assertion.],
  ),
) <not-enabled>

This models the intuition that view changes are triggered by "lack of progress",
without committing to a particular timing model.

On the new primary side, handling view-change messages collects two pieces of
information: i) `view_commits` which represents the longest commit sequence seen
among received messages and ii) `view_backlog`: any outstanding operation that
needs to be replayed.

Once the primary has enough _view-change_ ($2f+1$) contributors, it transitions
into the new view and broadcasts _new-view_ message to other replicas. If there
is a backlog, the primary uses `HonestPrimarySendBacklogPreprepare` to
re-propose the backlog entry as a fresh _pre-prepare_ for new sequence number
`seq + 1`. This design matches PBFT's intent: after view change, the new primary
must ensure that any operation that might have been prepared in the previous
view is either committed or re-proposed consistently.

The backlog pre-prepare is a slight modification from the original protocol,
where the #emph("pre-prepare")s are embedded in the _new-view_ messages. We
adopt this modification to allow secondaries to reuse the normal case
_pre-prepare_ handling logic. The new primary must behave honestly when sending
those backlogs, as otherwise the secondaries (in the original protocol) can
validate those backlog #emph("pre-prepare")s by checking the proof ($2f + 1$
prepares) from the _view-change_ messages embedded in the _new-view_ message.

= Miscellaneous <Misc>

We additionally applies several additional mechanisms to help keep the model
checker TLC exploration tractable.

== Runtime Bounds
For exhaustive model checking, we bound (i) the maximum sequence number, (ii)
the maximum view number. These bounds are encoded as `RuntimeConstraint` (in
@model.tla) and are set as TLC constraints during runs.

These bounds do not claim that PBFT only runs for finite number of views; they
are just a technique to keep the explored state space finite while still
covering representative executions, including at most one view change and
multiple commit rounds.

== Message Filtering
The model deterministically drops any messages that are obsolete via step
`NetworkGC` (in @pbft.tla). The filter is specified in the `IsUseless` statement
in @messages.tla. which filters out any messages that (i) have lower sequence
number or view number, or (ii) disagrees with the request data, or (iii) is a
_prepare_ message while the node already receives enough ($2f + 1$) #emph(
  "prepare",
)s.

== View Change Network
The model uses a dedicated network `ViewNetwork` to propagate _view-change_
messages and _new-view_ messages. This ensures the liveness of the view-change
protocol even if the main network queue is blocked with "useful" messages (with
future view number) that requires the secondaries to complete the view-change
before handling those messages.

== Symmetry Reduction
In many distributed protocols, several nodes play identical roles and differ
only by their identifiers. From the protocol's perspective, executions that
differ only by a permutation of these symmetric nodes are equivalent: they
exhibit the same behaviors and lead to the same correctness outcomes. Symmetry
reduction exploits this observation by exploring only one representative
execution from each equivalence class of symmetric states, rather than all
permutations. This can drastically decrease the size of state space to explore.

As we only model at most $1$ view changes, it suffies to allow only 2 (1 faulty)
out of the 4 nodes to be primary, and the remaining nodes can be symmetric. In
@model.tla we let the primary nodes to only include node with id `0` (faulty)
and `1` (honest), and set the remaining nodes to be symmetric nodes as they do
not differ funcionally.

= Validation <Validation>

We validated the following safety and liveness properties against our model.

== Safety Properties

=== Prepare invariant
states that no two different requests can both become prepared for the same view
and sequence number at honest replicas, where prepared means receiving $2f + 1$
consistent #emph("prepare")s for that request.

We introduced `NodeState[node].prepares` field that keeps track of for each node
the set of requests that have reached the prepared state.

This constraint is defined as `PrepareInv` (@PrepareInv), which asserts that for
any view and sequence number, the prepared sets of all honest replicas are
consistent. This invariant directly captures PBFT’s guarantee that equivocation
by Byzantine nodes cannot cause honest replicas to prepare conflicting requests.

=== Commit invariant
stats that a replica cannot commit a request locally (after receiving $2f + 1$
#emph("commit")s) unless at least $f + 1$ honest nodes are prepared for that
request.

This condition is crucial for two reasons. First, it ensures that even if
replicas commit in different views, they agree on the order of committed
requests. Second, it guarantees that any request committed by an honest replica
will eventually be committed by at least $f+1$ honest replicas overall, ensuring
durable agreement despite Byzantine faults.

We encode this condition as the invariant `CommitInv` (@CommitInv).

== Liveness Properties

=== Eventual commit
states that a client will eventually receive a reply to its request as mentioned
in PBFT paper @castro1999pbft. Since our model does not explicitly represent
clients, we capture this guarantee indirectly.

We model client request submission as the honest primary sending a pre-prepare
message, and we model client response as the same primary executing the request
and appending it to its local committed log. The liveness property
EventualCommit (@EventualCommit) asserts that every request initiated by an
honest primary is eventually committed.

=== No view change with honest primary
states that if the primary is honest, Byzantine replicas cannot prevent the
system from making progress. Since view-changes only occurs when the system is
stalled, no view-change can happen in this case.

This constraint is implemented in @HonestNoViewChange.

= Results <Results>

We evaluated our model under the minimal configuration with $f = 1$ Byzantine
node and in total $3f + 1 = 4$ nodes. We ran the TLA+ model checker TLC on a
16-core workstation, checking both safety-only configurations and configurations
that include liveness properties.

In this setup, two replicas (one of which is faulty) are eligible to act as
primary. When verifying safety properties alone, the remaining replicas are
declared symmetric to reduce the state space. Across all explored
configurations, TLC reported no violations of the proposed safety or liveness
properties.

Table @t:count summarizes the number of distinct states explored under different
bounds on the number of commits and view changes. Table @t:perf reports the
corresponding state-generation throughput achieved by TLC.

#figure(
  table(
    columns: (auto, auto, auto, auto, auto),
    table.header(
      [\#commits], [\#views], [Symmetric], [States], [Distinct states]
    ),
    "1", "2", "yes", "1.3M", "296K",
    "1", "2", "no", "2.7M", "589K",
    "2", "2", "yes", "12M", "3.6M",
    "2", "2", "no", "24M", "7.2M",
  ),
  caption: "Number of states",
) <t:count>

#figure(
  table(
    columns: (auto, auto, auto),
    table.header([], [States / min], [Distinct states / min]),
    "without liveness", "14M", "5M",
    "with liveness", "2M", "500K",
  ),
  caption: "TLC Performance",
) <t:perf>


= Discussion <Discussion>

== Performance

As shown in @t:count and @t:perf, the smallest profile (1 commits, without
liveness checks) takes about 6 seconds to complete, while the largesst profile
(2 commits, with liveness checks) spends around 14 minutes on state generation,
plus additional overhead for checking temporal formulas for liveness properties,
which takes more than 30 minutes in total.

This highlights a fundamental limitation of explicit-state model checking: even
in the smallest nontrivial PBFT configuration, allowing one additional committed
request increases the state space by roughly an order of magnitude due to the
explosion of possible interleavings. In practice, this means that scaling the
model by only a single extra commit quickly renders exhaustive exploration
infeasible, despite symmetry reduction and a minimal fault threshold.

State explosion therefore strongly shaped the design of our specification.
Throughout the model, we applied optimizations aimed at minimizing unnecessary
interleavings while preserving correctness. In particular, we made protocol
steps as atomic as possible, for example by merging the handling of a
pre-prepare message with the immediate broadcast of the corresponding prepare
messages. We also reused a uniform broadcast abstraction for faulty nodes,
avoiding additional branching that would otherwise arise from modeling
adversarial message choices in full detail. These optimizations were essential
to keep the state space tractable while still faithfully capturing the safety
and liveness properties of PBFT.

== Network Model

Our work adopted a FIFO, guarenteed delivery network model, which is stronger
than the eventual synchrony model mentioned in the original paper
@castro1999pbft. Below we discuss how this model can be systematically relaxed,
and why these relaxations do not affect the high-level correctness of the
protocol.

=== Reordering
Reordering can be modeled by replacing each FIFO network queue with an unordered
set of in-flight messages, where the receiver nondeterministically selects a
message to deliver. At the protocol level, replicas can tolerate such reordering
by interposing a network adapter that buffers incoming messages and releases
them only when they are processable according to the local state. This preserves
protocol semantics while eliminating the FIFO assumption.

=== Duplication
Packet duplication can be simulated by allowing the network adapter to deliver a
message without removing it from the underlying buffer. PBFT is explicitly
designed to handle such duplication: replicas record messages they have already
processed and ignore duplicates. Consequently, supporting message duplication
requires little to no change at the protocol level and can be naturally absorbed
by the same buffering and filtering logic used for reordering.

=== Loss
Message loss, and equivalently message corruption (which is detectable via
authentication), violates eventual synchrony unless compensated for. To restore
eventual synchrony, the network adapter must implement retransmission, resending
messages until they are acknowledged or become obsolete. This responsibility
lies below the protocol layer and does not alter PBFT's core logic.

Overall, these network behaviors can be cleanly encapsulated within a suitably
implemented network adapter. Since they do not affect the high-level operation
or correctness arguments of PBFT, it is safe for our model to omit them and rely
on a stronger FIFO, guaranteed-delivery abstraction for tractability.

== Protocol Limitations

A limitation of our current model is that we restrict the primary to handling at
most one request at a time: a new client request is not accepted until the
previous one has been fully executed. This effectively limits the protocol to a
single in-flight request, whereas the original PBFT protocol allows multiple
concurrent requests to be in different phases of the protocol. Although this
restriction could be lifted by augmenting `NodeState` to track multiple
outstanding requests, doing so would significantly increase the state space. In
particular, the #emph("pre-prepare") step would branch over multiple pending
requests, leading to more than a twofold increase in states that would further
compound in the prepare and commit phases. Accurately model checking this aspect
of PBFT would therefore require introducing additional determinism or
abstractions to control state explosion, which we leave as future work.

= Conclusion <Conclusion>

This work demonstrates that PBFT @castro1999pbft’s core safety and liveness
properties can be validated using explicit-state model checking in a carefully
designed TLA specification. By focusing on a minimal yet representative
configuration and by introducing targeted abstractions and auxiliary state, we
were able to check key invariants and reason about protocol correctness under
realistic fault assumptions. At the same time, our results make clear that state
explosion is the dominant challenge: even modest increases in concurrency or
protocol fidelity lead to rapid growth in the state space. This motivated a
series of modeling choices and optimizations that trade completeness for
tractability while preserving the protocol’s high-level behavior. Overall, our
study highlights both the feasibility and the limits of model checking for
complex Byzantine fault-tolerant protocols, and it points to future work on
stronger abstractions and determinism techniques to scale verification to richer
protocol behaviors.

Future work can build on this foundation in several directions. One immediate
extension is to relax modeling restrictions, such as the single in-flight
request assumption, and to explore more faithful representations of PBFT’s
concurrency while controlling state explosion through additional determinism or
abstraction techniques. Beyond the base protocol, the modeling approach can be
applied to PBFT variants and modern Byzantine fault-tolerant systems, including
blockchain consensus protocols that involve dynamic membership.

#bibliography("refs.bib")

#set page(columns: 1)

= Code Snippets

== Prepare Invariant <PrepareInv>

```
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
```

== Commit Invariant <CommitInv>

```
Prepared(data, view_, seq, node) ==
    LET nodeState == NodeState[node] IN
        IF Len(nodeState.prepares) = 0
            THEN FALSE
            ELSE \E i \in 1..Len(nodeState.prepares) :
                nodeState.prepares[i] = [data |-> data, view |-> view_, seq |-> seq]

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
```

== No View Change with Honest Primaries <HonestNoViewChange>

```
HonestNoViewChange == [] (View0 \subseteq Honest) => \A node \in Nodes : primary!GetPrimary(node) \in View0
```

== Eventual commit <EventualCommit>

```
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
```

#pagebreak()

= Code Listings

The source code can be found at @csc2125-project.

== The main specification <pbft.tla>

#raw(read("./pbft/pbft.tla"))
#pagebreak()

== Network model <network.tla>

#raw(read("./pbft/network.tla"))
#pagebreak()

== Primary model <primary.tla>

#raw(read("./pbft/primary.tla"))
#pagebreak()

== Secondary model <secondary.tla>

#raw(read("./pbft/secondary.tla"))
#pagebreak()

== Messages model <messages.tla>

#raw(read("./pbft/messages.tla"))
#pagebreak()

== View change specification <view.tla>

#raw(read("./pbft/view.tla"))
#pagebreak()

== Timestamp counter <tsc.tla>

#raw(read("./pbft/tsc.tla"))
#pagebreak()

== Utilities <util.tla>

#raw(read("./pbft/util.tla"))
#pagebreak()

== Model specification <model.tla>

#raw(read("./pbft/model.tla"))
#pagebreak()

== TLC configuration

#raw(read("./pbft/model.cfg"))
#raw(read("./pbft/liveness.cfg"))

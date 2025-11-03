# csc2125-project

## Formal verification on (p)BFT consensus protocols

This project aims to formally verify the safety and liveness properties of the Practical Byzantine Fault Tolerance [^1] algorithm and extend the verification framework to ByzCoin’s consensus variant [^2]. PBFT forms the backbone of many Byzantine fault-tolerant systems, while ByzCoin modifies PBFT by introducing collective signing for scalability. The project’s first milestone will model PBFT formally, prove correctness invariants, and simulate network and adversarial behaviors. ByzCoin verification will serve as a stretch goal, reusing the PBFT framework to assess how collective signing impacts fault tolerance and performance.

We will develop a TLA+ [^3] specification of PBFT that captures the core protocol phases under partial synchrony and bounded Byzantine faults. The focus will be on proving key correctness properties: safety (agreement, integrity, and validity) and liveness (eventual decision under stable network conditions). The model will abstract cryptographic primitives and network behavior to maintain tractability while retaining enough detail to reason about message order, quorum thresholds, and adversarial faults.

By the end of the project, we will deliver a complete model and verified invariants for PBFT, along with documentation of assumptions, proof structure, and parameter bounds. If time permits, the model will be extended to represent ByzCoin’s collective signing phase, assessing whether PBFT’s proven properties still hold under this modification. The final report will present the formal proofs, discuss trade-offs between scalability and verifiability, and outline directions for full verification of ByzCoin’s dynamic reconfiguration in future work.

[^1]: [PBFT paper](http://pmg.csail.mit.edu/papers/osdi99.pdf)
[^2]: [ByzCoin paper](https://www.usenix.org/system/files/conference/usenixsecurity16/sec16_paper_kokoris-kogias.pdf)
[^3]: [TLA+](https://lamport.azurewebsites.net/tla/tla.html) [IDE](https://github.com/tlaplus/tlaplus)

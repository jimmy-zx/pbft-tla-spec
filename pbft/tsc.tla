-------------------------------- MODULE tsc --------------------------------

EXTENDS Naturals

VARIABLES TSC

Init == TSC = 1

\* Next == TSC' = TSC + 1
Next == TSC' = TSC

TypeOK == TSC \in Nat

=============================================================================

-------------------------------- MODULE util --------------------------------

EXTENDS Naturals, Sequences, TLC


SelectSeqArg(s, Test(_, _), args) ==
  LET F[i \in 0..Len(s)] ==
        IF i = 0 THEN << >>
                 ELSE IF Test(s[i], args)
                    THEN Append(F[i-1], s[i])
                    ELSE F[i-1]
  IN F[Len(s)]

IsSubseq(super, sub) ==
    IF Len(sub) = 0
        THEN TRUE
        ELSE
            IF Len(super) = 0
                THEN FALSE
                ELSE
                    /\ Assert(Len(super) >= Len(sub), "")
                    /\ \A i \in 1..Len(sub) : super[i] = sub[i]

AgreeOn(lhs, rhs) ==
    IF Len(lhs) >= Len(rhs)
        THEN IsSubseq(lhs, rhs)
        ELSE IsSubseq(rhs, lhs)

MaxSeq(lhs, rhs) ==
    IF Len(lhs) >= Len(rhs)
        THEN lhs
        ELSE rhs

=============================================================================

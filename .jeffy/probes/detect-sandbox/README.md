# detect-sandbox

Known-answer battery for `skills/jeffy/hooks/lib/detect-sandbox.sh`. The
launcher records this detector's answer as `sandboxed` in the loop state, and
its `no` is what makes the launch banner print the blast-radius sentence
SECURITY.md backs. A detector that answered `yes` wrongly would silence that
sentence on an unsandboxed host, which is the one direction that matters.

## The difficulty this battery is shaped around

Only one of the script's four branches is reachable on any given host. Driving
the real script therefore establishes one branch and the documented parameter,
and nothing about the other three. The arms are split three ways and each says
which kind it is, so a reader can tell evidence about the shipped file from
evidence about its branch logic:

- **The real script on this host.** The documented parameter is driven on both
  sides, and the host's own branch is classified by re-deriving the same four
  conditions the script tests, then asserted to produce the answer that branch
  owes. The classification is printed, so a failing run distinguishes a moved
  branch from a moved host.
- **The container pattern, extracted by command.** The alternation is taken out
  of the file rather than retyped, asserted non-empty first, and driven over
  fixture cgroup content: each runtime it names matches, and a plain systemd
  line, an empty file and a WSL-style `0::/` do not. The non-empty guard is
  load-bearing - an empty pattern makes `grep -qE` match everything, so the
  negative arms would pass for the worst possible reason.
- **A path-rewritten copy**, every arm labelled `rewritten copy:`. The three
  filesystem probes are redirected into a fixture so the branches this host
  cannot reach are exercised at all. These arms are evidence about the branch
  logic and about the precedence between branches; they are never a claim that
  the shipped script was observed taking that branch here. The copy is checked
  to parse, to differ from the shipped file, and to have actually had its paths
  substituted - a rewrite that substituted nothing would silently read the real
  host and every arm would report the host's single answer.

## What it drives

`JEFFY_SANDBOXED` is the one input an operator sets, and the contract is that
the literal `1` wins and nothing else does. It is driven at `1` and then at
`0`, `yes`, `true`, the empty string, `11`, `" 1"` and `1x`, each of which must
leave the host's own answer standing. Driving only the positive value would
pass a truthiness test or a prefix match just as well.

The answer set is derived from the file - comment lines stripped, so a comment
naming an answer cannot manufacture a fourth - and required to be exactly
`no unknown yes`, with a separate arm asserting the file emits through no other
output statement. That keeps this battery honest against the same drift check Q
derives from the same file for the documents that publish the set.

Precedence is asserted, not just per-branch behaviour: an explicit declaration
beats a clean cgroup, and a marker file beats a clean cgroup. A per-branch test
cannot make either claim.

## What it was observed failing on

Recorded at creation; each is replayed by a line in `claims`, and each was
confirmed to parse and to differ from the shipped file before its result
counted.

- Replacing the `= "1"` test with `-n` makes every non-empty value answer
  `yes`, which the six negative-value arms report at once.
- Dropping `podman` from the container alternation falls only the podman arm,
  which is the per-runtime resolution the extracted-pattern arms exist for.
- Deleting the container-cgroup branch entirely falls the rewritten-copy arm
  for a container cgroup, and is caught first by the pattern-extraction guard,
  since with the branch gone there is no alternation to extract.
- Turning the final `echo unknown` into `echo no` falls the answer-set arm and
  both no-signal arms, so a host with no signal would be reported as genuinely
  not containerised.
- Turning the clean-cgroup `echo no` into `echo unknown` falls the answer-set
  arm and this host's own branch arm.

## What it cannot reach

No arm drives a real container. The marker-file and container-cgroup branches
are established on the rewritten copy alone, so what is proven is that the
logic answers correctly given those conditions, not that a real Docker
container presents them - that needs a run inside one. macOS and Windows take
the `unknown` fall-through and neither is reachable here either; the
rewritten-copy no-signal arm is the closest this host can come to them.

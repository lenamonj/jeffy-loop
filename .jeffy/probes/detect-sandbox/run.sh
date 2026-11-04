#!/usr/bin/env bash
# Known-answer battery for skills/jeffy/hooks/lib/detect-sandbox.sh, the
# shipped detector whose answer the launcher records in the loop state and
# whose `no` is what makes the launch banner print the blast-radius sentence.
#
# The honest difficulty with this file is that only one of its four branches is
# reachable on any given host, so the arms are split three ways and each says
# which it is:
#   - the real script on this host, where the documented parameter and the
#     host's own branch are driven for real;
#   - the container-detection pattern, extracted from the script by command
#     rather than retyped, driven over fixture content with known answers;
#   - a path-rewritten copy, labelled `rewritten copy:`, where the three
#     filesystem probes are redirected into a fixture so the branches this host
#     cannot reach are still exercised. Those arms are evidence about the
#     branch logic and the ordering, never a claim that the shipped script was
#     observed taking that branch here.
set -u
ds_root="${JEFFY_PROBE_ROOT:-$PWD}"
ds_sh="$ds_root/skills/jeffy/hooks/lib/detect-sandbox.sh"
[ -f "$ds_sh" ] || { echo "detect-sandbox battery: no $ds_sh"; exit 2; }

ds_ok=0; ds_bad=0
ck() { # $1 label, $2 expected, $3 actual
  if [ "$2" = "$3" ]; then ds_ok=$((ds_ok + 1)); else
    ds_bad=$((ds_bad + 1)); echo "FAIL $1: expected [$2] got [$3]"
  fi
}
ds_tmp="$(mktemp -d)" || exit 2
trap 'rm -rf "$ds_tmp"' EXIT

ds_run() { # answer on stdout; stderr and status captured separately
  env "$@" bash "$ds_sh" 2>"$ds_tmp/err"
}

# --- 1. the answer set is exactly the three the contract names ---------------
# Extracted from the file rather than written here, and asserted non-empty
# first, because a pattern that matched nothing would make the set agree by
# being empty. Comment lines are stripped, so a comment naming an answer
# cannot manufacture a fourth.
ds_answers="$(grep -vE '^[[:space:]]*#' "$ds_sh" | grep -oE 'echo [a-z]+' | sed 's/^echo //' | sort -u | tr '\n' ' ')"
ck "the answer set is non-empty" 1 "$([ -n "$ds_answers" ] && echo 1 || echo 0)"
ck "the answer set is exactly no, unknown, yes" "no unknown yes " "$ds_answers"
ck "no other output statement in the file" 0 \
  "$(grep -vE '^[[:space:]]*#' "$ds_sh" | grep -cE '(printf|cat|tee)[[:space:]]' || true)"

# --- 2. the documented parameter, on the real script ------------------------
# JEFFY_SANDBOXED is the one input an operator sets, and the contract is that
# the literal 1 wins and nothing else does. Driven on both sides rather than
# only on the value that answers yes, because a test that compares a prefix or
# truthiness would pass the positive arm alone.
ds_host="$(bash "$ds_sh")"
ck "this host answers one of the three" 1 \
  "$(case " $ds_answers" in *" $ds_host "*) echo 1 ;; *) echo 0 ;; esac)"
ck "an explicit declaration answers yes" yes "$(ds_run JEFFY_SANDBOXED=1)"
ck "an explicit declaration exits 0" 0 "$(ds_run JEFFY_SANDBOXED=1 >/dev/null; echo $?)"
ck "an explicit declaration says nothing on stderr" 0 "$(wc -c < "$ds_tmp/err")"
for ds_v in 0 yes true "" 11 " 1" 1x; do
  ck "JEFFY_SANDBOXED=[$ds_v] does not answer yes" "$ds_host" "$(ds_run "JEFFY_SANDBOXED=$ds_v")"
done
ck "unset answers the host's own branch" "$ds_host" "$(ds_run)"
ck "the host answer exits 0" 0 "$(bash "$ds_sh" >/dev/null 2>&1; echo $?)"
ck "the answer is exactly one line" 1 "$(bash "$ds_sh" 2>/dev/null | grep -c .)"
ck "nothing on stderr on the host path" 0 "$(bash "$ds_sh" 2>&1 >/dev/null | wc -c)"

# This host's branch is recorded as a fact about the host, derived here rather
# than assumed, so a reader of a failing run can tell a moved branch from a
# moved host.
ds_branch=other
if [ -f /.dockerenv ] || [ -f /run/.containerenv ]; then ds_branch=marker-file
elif [ -r /proc/1/cgroup ] && grep -qE '(docker|containerd|kubepods|lxc|podman)' /proc/1/cgroup 2>/dev/null; then ds_branch=cgroup-match
elif [ -r /proc/1/cgroup ]; then ds_branch=cgroup-clean
else ds_branch=no-signal
fi
case "$ds_branch" in
  marker-file|cgroup-match) ck "branch $ds_branch answers yes" yes "$ds_host" ;;
  cgroup-clean)             ck "branch cgroup-clean answers no" no "$ds_host" ;;
  no-signal)                ck "branch no-signal answers unknown" unknown "$ds_host" ;;
  *) ck "host branch classified" 1 0 ;;
esac
echo "  host branch: $ds_branch, answer: $ds_host"

# --- 3. the container pattern, extracted and driven -------------------------
# The pattern is the discriminating part of the cgroup branch, and it is taken
# out of the file by command so a drift in the file reaches this arm.
ds_pat="$(grep -oE "\(docker\|[a-z|]+\)" "$ds_sh" | head -n 1)"
ck "the container pattern was extracted" 1 "$([ -n "$ds_pat" ] && echo 1 || echo 0)"
ds_hit() { printf '%s\n' "$2" > "$ds_tmp/cg"; grep -qE "$ds_pat" "$ds_tmp/cg" && echo yes || echo no; }
for ds_rt in docker containerd kubepods lxc podman; do
  ck "pattern matches a $ds_rt cgroup line" yes "$(ds_hit "$ds_rt" "0::/system.slice/$ds_rt-abc.scope")"
done
ck "pattern ignores a plain systemd cgroup" no "$(ds_hit systemd "0::/init.scope")"
ck "pattern ignores an empty cgroup file" no "$(ds_hit empty "")"
ck "pattern ignores a WSL-style cgroup" no "$(ds_hit wsl "0::/")"

# --- 4. the unreachable branches, on a path-rewritten copy ------------------
# The three filesystem probes are redirected into a fixture. This is a modified
# program and every arm below says so; what it establishes is the branch logic
# and the ordering between branches, which no amount of driving the real script
# on one host can reach.
ds_fix="$ds_tmp/fix"; mkdir -p "$ds_fix/run" "$ds_fix/proc/1"
ds_copy="$ds_tmp/rewritten.sh"
sed -e "s|/\\.dockerenv|$ds_fix/.dockerenv|g" \
    -e "s|/run/\\.containerenv|$ds_fix/run/.containerenv|g" \
    -e "s|/proc/1/cgroup|$ds_fix/proc/1/cgroup|g" "$ds_sh" > "$ds_copy"
if ! bash -n "$ds_copy" 2>/dev/null; then
  echo "FAIL the path-rewritten copy does not parse, so its arms prove nothing"
  ds_bad=$((ds_bad + 1))
elif ! grep -q "$ds_fix/proc/1/cgroup" "$ds_copy"; then
  echo "FAIL the path rewrite substituted nothing, so its arms would read the real host"
  ds_bad=$((ds_bad + 1))
else
  ck "rewritten copy: differs from the shipped file" 1 "$(cmp -s "$ds_copy" "$ds_sh" && echo 0 || echo 1)"
  ds_rw() { env "$@" bash "$ds_copy" 2>/dev/null; }
  ds_clear() { rm -f "$ds_fix/.dockerenv" "$ds_fix/run/.containerenv" "$ds_fix/proc/1/cgroup"; }

  ds_clear; ck "rewritten copy: no signal at all answers unknown" unknown "$(ds_rw)"
  ds_clear; : > "$ds_fix/.dockerenv"
  ck "rewritten copy: a docker marker file answers yes" yes "$(ds_rw)"
  ds_clear; : > "$ds_fix/run/.containerenv"
  ck "rewritten copy: a podman marker file answers yes" yes "$(ds_rw)"
  ds_clear; printf '0::/system.slice/docker-abc.scope\n' > "$ds_fix/proc/1/cgroup"
  ck "rewritten copy: a container cgroup answers yes" yes "$(ds_rw)"
  ds_clear; printf '0::/init.scope\n' > "$ds_fix/proc/1/cgroup"
  ck "rewritten copy: a clean readable cgroup answers no" no "$(ds_rw)"
  # Ordering: the explicit declaration has to beat every probe beneath it, and
  # a marker file has to beat a clean cgroup. Both are claims about precedence
  # that a per-branch test cannot make.
  ck "rewritten copy: a declaration beats a clean cgroup" yes "$(ds_rw JEFFY_SANDBOXED=1)"
  : > "$ds_fix/.dockerenv"
  ck "rewritten copy: a marker file beats a clean cgroup" yes "$(ds_rw)"
  ds_clear
  # An unreadable cgroup is not the same as an absent one on a host that has
  # the file; both must fall through to unknown rather than to no.
  printf '0::/init.scope\n' > "$ds_fix/proc/1/cgroup"
  if chmod 000 "$ds_fix/proc/1/cgroup" 2>/dev/null && [ ! -r "$ds_fix/proc/1/cgroup" ]; then
    ck "rewritten copy: an unreadable cgroup answers unknown" unknown "$(ds_rw)"
  else
    echo "SKIP unreadable-cgroup arm: this filesystem or user ignored mode 000"
  fi
  chmod 644 "$ds_fix/proc/1/cgroup" 2>/dev/null
fi

if [ "$ds_bad" -eq 0 ]; then
  echo "detect-sandbox battery: $ds_ok/$ds_ok checks passed"
  exit 0
fi
echo "detect-sandbox battery: $ds_bad of $((ds_ok + ds_bad)) checks failed"
exit 1

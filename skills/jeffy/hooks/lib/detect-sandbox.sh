#!/usr/bin/env bash
# detect-sandbox.sh - print yes, no, or unknown: is this session inside a
# container or an explicitly declared sandbox?
#
# Why the engine cares. Jeffy runs unattended over repositories the operator
# often did not write, and an unattended agent usually runs with permissions
# relaxed. Once they are, the sandbox is the only remaining boundary, and what
# sits outside it is the whole machine - credentials, SSH keys, browser
# cookies, tokens. This does not block anything and never will: the loop does
# not widen its own mandate, and it has no business narrowing the operator's
# either. It states the blast radius once, at launch, and lets a person decide.
#
# Three answers rather than two, on purpose. "unknown" is the honest reading
# of a host that provides no signal either way, and reporting it as "no" would
# be the kind of confident wrong answer this project refuses everywhere else.
set -u

# An explicit declaration wins: an operator who has built their own boundary
# knows more about it than any probe here does.
if [ "${JEFFY_SANDBOXED:-}" = "1" ]; then
  echo yes
  exit 0
fi

# Docker and Podman both leave this behind.
if [ -f /.dockerenv ] || [ -f /run/.containerenv ]; then
  echo yes
  exit 0
fi

# cgroup naming catches most container runtimes on Linux.
if [ -r /proc/1/cgroup ] && grep -qE '(docker|containerd|kubepods|lxc|podman)' /proc/1/cgroup 2>/dev/null; then
  echo yes
  exit 0
fi

# A Linux host with a readable init cgroup and no container marker in it is
# genuinely not containerised, which is a real "no" rather than a shrug.
if [ -r /proc/1/cgroup ]; then
  echo no
  exit 0
fi

# Everything else - macOS, Windows, an unreadable procfs - cannot be told
# apart from here, and says so.
echo unknown

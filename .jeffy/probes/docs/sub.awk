# Replace the first literal occurrence of `old` with `new`. index() rather than
# a regex because the lines these mutations target carry $, (, ), [, ] and ";
# an escaping that must survive being copied into a state file is one that will
# be lost.
{ i = index($0, old); if (i > 0 && !done) { $0 = substr($0, 1, i - 1) new substr($0, i + length(old)); done = 1 } print }

# Journal archive

Rotated entries, appended and never overwritten. The live journal is JOURNAL.md.

## iter 1/10 | 67f3ba7a-142257 | 2026-08-08 | AUDIT | audit

Task: First full audit of goccy/go-yaml. Filled the Operating envelope, the Verify command and the Surface inventory, then swept breadth-first with known-answer batteries.

Changed: PLAN.md (envelope surfaces, verify command, 30 inventory rows), BACKLOG.md (3 findings, 1 settled class), .jeffy/probes/{encode-options,decode-options,token-scalars} (green batteries, with paths files), .jeffy/probes/{scalar-roundtrip,smart-anchor,reference-file-handles} (red repro batteries, no paths file yet so they gate nothing until their fix lands), .gitignore.

Checkpoint: a2e825bea146fdb967a739e385e09435ca14e68f

Verification: Baseline `go test ./...` and `go test ./testdata -modfile=testdata/go_test.mod` both exit 0, as do `go build ./...` and `go vet ./...`. Green batteries: encode-options, decode-options, token-scalars all exit 0. Red batteries reproducing the filed findings: scalar-roundtrip, smart-anchor, reference-file-handles all exit 1.

Scores, claiming only the 3 swept rows of 30: correctness High (BUG-01, BUG-02), error handling Medium (BUG-03), architecture None, code quality None, security None, testing None, performance None, documentation None, dependency hygiene None (the library module has no third-party requirements; `cat go.sum` is empty and the validator dependency is confined to the separate testdata module), developer experience None, observability not applicable to a serialisation library, UX and accessibility not applicable - no user-facing surface beyond cmd/ycat, which is unswept. 27 of 30 rows are unswept, so every None above claims the three swept rows alone and says nothing about the remainder.

Learnings: The Go tool skips dot-directories when expanding `./...` but still resolves an explicit relative path, so `.jeffy/probes/<slug>/` batteries run via `go test ./.jeffy/probes/<slug>/` while staying invisible to the project's own gate. Two apparent findings dissolved on investigation and are recorded so a later audit does not re-file them: `UseSingleQuote` looked inert until probed with a string that actually requires quoting, and `DetectLineBreakCharacter` returning "\r\n" for a string with no line break is unreachable because every caller guards with a Contains check first. The `1e3` untyped-resolution question resolved to intended behaviour and is recorded under Settled classes.

Next: BUG-01, the block-scalar representability class, is the top item.

## iter 2/10 | 67f3ba7a-142257 | 2026-08-08 | BUG-01 | done

Task: BUG-01 (High) closed - the encoder chose literal block scalar style for strings that style cannot carry unchanged, so Marshal emitted documents that either failed to parse or decoded to a different string. Fixed as a class at the style-selection boundary rather than per instance.

Changed: encode.go (new unexported `canUseBlockStyle` predicate; `isNeedQuoted` consults it before the literal-style option; `encodeString` sends an unrepresentable value to double quotes even under UseSingleQuote), option.go (doc comments for UseLiteralStyleIfMultiline and UseSingleQuote now state the exception), encode_test.go (two CR expectations corrected), .jeffy/probes/scalar-roundtrip (generated enumeration added, `paths` file added now that it is green), .jeffy/probes/single-quote-escapes (new red battery for BUG-04), PLAN.md, BACKLOG.md.

Checkpoint: b07f1d37a8a8414d3eaa43c978d4757fe54c32cb

Verification: The enumeration was derived by provoking failures over a generated corpus of 900 multiline values crossed with 2 styling modes, not by reading the encoder: 925 of those 1800 cases were broken before the fix and 0 after, with the failing shapes falling into exactly four rules - a value containing CR, a value whose first non-empty line is indented, a value that is nothing but line breaks, and a value ending in white space. The candidate predicate was measured against that corpus before implementation and missed 0 of the 925. Acceptance check `go test ./.jeffy/probes/scalar-roundtrip/` exits 0, having exited 1 at the start of this iteration. Verify command exits 0. Batteries owning the changed paths - encode-options, decode-options, scalar-roundtrip - all exit 0. `go vet ./...` exits 0.

Verify gate: the first run after the fix was red, with exactly two TestEncoder subtests failing. Both were repaired inside this iteration under the pre-existing-fault exception, with this differential evidence: the documents those tests demanded, `hello: |\r  hello\r  world` and `hello: |\r\n  hello\r\n  world`, both decode to "hello\nworld\n" rather than the "hello\rworld\r" and "hello\r\nworld\r\n" they claimed to encode, so they pinned the defect itself; the replacement double-quoted forms decode to exactly the values they encode. No other test changed status in either direction - the pre-repair run failed those two subtests alone.

Contract preserved: `isNeedQuoted` keeps its single caller `encodeString` and its signature; `encodeString` still returns an *ast.StringNode and is unchanged for every value a block scalar can carry, so map keys, struct field names and ordinary scalars encode byte-identically. Only strings that previously round-tripped incorrectly changed style, which is an observable public behaviour change recorded here per the Constraints, and both affected option doc comments were corrected in the same iteration.

Learnings: A defect class is worth deriving rather than listing - the three instances filed in iteration 1 turned out to be four rules, and the fourth (trailing white space) appeared only in the generated corpus. Never read `$?` on a line that also runs a command substitution; doing so once reported three red batteries as green.

Next: BUG-02, the WithSmartAnchor unparseable output, is the top item. BUG-04 was found while fixing BUG-01 and is filed at High.

## iter 3/10 | 67f3ba7a-142257 | 2026-08-08 | BUG-02 | done

Task: BUG-02 (High) closed - yaml.WithSmartAnchor emitted unparseable YAML for map values sharing a pointer.

Changed: encode.go (encodeMap no longer wraps an already-encoded alias in an anchor; setSmartAnchor no longer re-registers a pointer that already owns an anchor name), .jeffy/probes/smart-anchor (three contract tests added, header corrected, `paths` file added now that it is green), BACKLOG.md.

Checkpoint: 44f74c1967a64c58da252978dbdda353df151ed6

Verification: Two distinct defects, both traced through the option's two-pass encode. First, clearSmartAnchorRef resets the anchor maps between passes but not aliasRefToName, so in pass two every occurrence of the shared pointer matched getSmartAlias and each was wrapped in an anchor - including the occurrence encodePtrAnchor had already turned into an alias, producing `b: &a *a`, which the parser rejects with "unexpected scalar value type". Second, setSmartAnchor overwrote the pointer's registration on every later key, so with three keys the anchor was named after a later key while the aliases already referred to an earlier one, giving `a: &b`, `b: &a *a`, `c: &b *b` - two defects, each of which alone still leaves the output broken, which is why both were fixed together. Acceptance check `go test ./.jeffy/probes/smart-anchor/` exits 0, having exited 1 at the start of this iteration with 20 of 20 randomised map orderings failing to re-parse. The battery now also pins the rest of the documented contract with fresh evidence: the anchor takes the first occurrence's key name (`&alpha` for keys alpha/mid/zeta, with two `*alpha` aliases and no anchor on the later keys), colliding key names get the documented suffix (`&dup` and `&dup1` for two distinct shared pointers both first seen under "dup"), and a reused Encoder emits two independent documents that both decode. Verify command exits 0 on the first run, `go vet ./...` exits 0, and the batteries owning the changed path - encode-options, decode-options, scalar-roundtrip, smart-anchor - all exit 0.

Contract preserved: both changed sites are reached only when enableSmartAnchor is true - setSmartAnchor returns early otherwise, and the encodeMap branch needs a getSmartAlias hit, which needs the option - so encoding without WithSmartAnchor is byte-identical. The explicit anchor and alias struct tags go through setAnchor directly and are untouched, which the pre-existing TestSmartAnchor in yaml_test.go confirms: it pins a nine-level anchored-sequence document and passed unchanged, because a sequence holding aliases is not itself an alias node and still receives its anchor. No documentation changed, because the fix makes the code match what WithSmartAnchor already documented.

Learnings: When a feature keeps two maps across a clear-and-replay boundary, check what the clear does not clear - the surviving aliasRefToName was the whole defect, and the second bug was invisible until the first was fixed, so both needed the same iteration.

Next: BUG-04, the single-quote escaping corruption, is the top item.

## iter 4/10 | 67f3ba7a-142257 | 2026-08-08 | BUG-04 | done

Task: BUG-04 (High) closed - yaml.UseSingleQuote(true) emitted Go escape sequences inside single-quoted scalars, which YAML does not interpret, so those documents decoded to different strings.

Changed: encode.go (new canUseSingleQuote and singleQuoted; encodeString gates on them), option.go (UseSingleQuote doc comment restated around the real rule), stdlib_quote.go deleted, .jeffy/probes/single-quote-escapes (header corrected, `paths` file added now that it is green), PLAN.md (the scalar-styling row's scope command named the deleted file), BACKLOG.md.

Checkpoint: b40d1926e61df3a542feb63916082c3a5594ed65

Verification: The root cause is in the copied stdlib escaper: appendEscapedRune had been patched to double the quote character, which is correct YAML, but its non-printable branch below still emitted Go escapes, so every rune failing unicode.IsPrint - line breaks, tab, control bytes, and non-ASCII space - was written as a backslash sequence that single-quoted style reads as literal text. The project already had a spec-correct escaper in ast.escapeSingleQuote, which only doubles the quote; the encoder simply did not use it. The fix admits single quotes only for values that are valid UTF-8 and entirely printable, and renders those by doubling the quote, which makes the copied file unreachable, so it was deleted after confirming `grep -rn 'quoteWith\|appendQuotedWith\|appendEscapedRune'` returns no caller outside the file itself. Acceptance check `go test ./.jeffy/probes/single-quote-escapes/` exits 0, having exited 1 at the start of this iteration with 120 of the 900 generated corpus values corrupted. Verify command exits 0 on the first run, `go vet ./...` exits 0, all 7 batteries were run and only reference-file-handles is red, which is BUG-03 and still open.

Differential evidence for the deletion and the widened gate: the single-quote encoding of 2211 printable values was captured before the change and replayed after. 131 differed, all of one shape - a value with a leading or trailing space, which the previous iteration's narrower gate had sent to double quotes and which single-quoted style carries literally - and all 2211 round trip after the change, 0 bad. So no value lost a working encoding; 131 gained the style the option asks for.

Contract preserved: UseSingleQuote still yields single-quoted output for every value single quotes can carry, and the pre-existing encode_test case pinning `a: '\.yaml'` passed unchanged, since a backslash is printable and needs no escape in that style. stdlib_quote.go held no exported identifier, so deleting it changes no public API. The doc comment was rewritten in the same iteration because the rule it stated, inherited from the BUG-01 fix, is no longer the rule the code applies.

Learnings: A patched copy of third-party code is worth re-reading past the patch - the comment in stdlib_quote.go explained exactly why the backslash branch was wrong for YAML and then left the non-printable branch below it untouched. When a fix makes copied code unreachable, deleting it is part of the fix: leaving a broken escaper in the tree invites the next caller to reintroduce the defect.

Next: BUG-03, the reference-file descriptor leak, is the only open task. The ledger is below three items, so iteration 5 replenishes with a partial audit targeting unswept Surface inventory rows.

## iter 5/10 | 67f3ba7a-142257 | 2026-08-08 | BUG-03 | done

Task: BUG-03 (Medium) closed - the decoder opened every ReferenceFiles and ReferenceDirs file and never released the handle, leaking one descriptor per referenced file per decode.

Changed: decode.go (fileToReader now reads the file into memory and returns a bytes.Reader instead of handing out the open *os.File), .jeffy/probes/reference-file-handles (ownership and volume checks added, header corrected, `paths` file added now that it is green), .jeffy/probes/decode-options (restored t.TempDir, whose comment blamed this leak and is no longer true), PLAN.md (DecodeOption row flipped back to unswept, stale since decode.go changed), BACKLOG.md.

Checkpoint: b2ad02ba826915d5e4cc93956575fb4133790db8

Verification: The class was enumerated across the whole project rather than assumed local: `grep -rn 'os\.Open\|os\.Create\|os\.ReadFile' --include='*.go'` over non-test sources returns four sites, and three of them - cmd/ycat, parser.ParseFile and the yaml-test-suite loader - already use os.ReadFile, which closes internally. decode.go was the single member of the class. Closing the pooled readers would have been the wrong shape: d.referenceReaders mixes decoder-opened files with readers the caller passed to ReferenceReaders, which the decoder does not own, so reading eagerly and never holding a descriptor is the only correct fix. resolveReference already calls io.ReadAll on every reader, so nothing was streamed and no behaviour depended on the lazy handle. Acceptance check `go test ./.jeffy/probes/reference-file-handles/` exits 0, having exited 1 at the start of this iteration on three separate checks - the Windows delete probe for ReferenceFiles, the same for ReferenceDirs, and the structural check that decode.go calls os.Open without any Close. The battery now also pins the ownership contract the fix's comment claims, with a recording io.ReadCloser proving a caller-supplied reader is left open, and runs 300 successive decodes against one reference file to exercise the consequence the leak actually had. Verify command exits 0 on the first run, `go vet ./...` exits 0, and all 7 batteries are green for the first time this run.

Contract preserved: fileToReader keeps its signature and its two callers, resolveReference and readersUnderDir/readersUnderDirRecursive, and still returns an io.Reader over the file's bytes, so anchor resolution is unchanged - the decode-options battery, which drives ReferenceFiles, ReferenceDirs and RecursiveDir at two values each, passes unchanged. The only observable difference is that a read error now surfaces from fileToReader rather than from the later io.ReadAll, which fails earlier and names the file. No public API changed, so no documentation needed updating.

Learnings: When a leak lives in a pool of mixed-ownership handles, the fix is to stop putting owned handles in the pool, not to find a place to close them. A stale comment in a probe battery is as misleading as one in shipped code: the decode-options battery had been steered away from t.TempDir by this very bug and had to be restored in the same iteration the bug died.

Next: the ledger is empty and 29 of 30 Surface inventory rows are unswept, so iteration 6 runs an audit that sweeps unswept rows with known-answer batteries, starting with the encoder and decoder rows this run has been changing.

## iter 6/10 | 67f3ba7a-142257 | 2026-08-08 | AUDIT | audit

Task: Replenishing audit on an empty ledger. Swept eight Surface inventory rows with new and existing known-answer batteries and filed what the sweep found.

Changed: .jeffy/probes/path-query (new green battery, with paths file), .jeffy/probes/core-api (new green battery, with paths file), .jeffy/probes/path-wrapper-nodes (new red repro battery, no paths file yet), PLAN.md (eight rows flipped to swept at 05ca010640747db8d03f1e55507059d3b257c560), BACKLOG.md (PATH-01, PATH-02).

Checkpoint: a1d5dad428ada6fd085e14e05790be5179404158

Verification: Rows swept this iteration, all at 05ca010640747db8d03f1e55507059d3b257c560: EncodeOption family, DecodeOption family, encoder scalar styling and quoting, JSON bridge and RawMessage, MapSlice and MapItem, Path read and filter, Path merge and replace plus PathBuilder, and error predicates and formatting. That is 9 of 30 rows swept, up from 1. Verify command exits 0, and all 10 batteries were run: 9 green and only path-wrapper-nodes red, which is the repro for the two findings filed below.

Findings: PATH-01 and PATH-02, both Medium, one root cause. selectorNode.filter and selectorNode.replace dispatch on node.Type() and route anything that is not a mapping or sequence to an "invalid query" error, so Path cannot traverse the wrapper nodes YAML puts in front of a value. The enumeration was built by provoking a failure on every shape rather than by reading the switch: of nine read queries, `$.anc.k`, `$.tagged.k`, `$.seqanc[0]`, `$.ali.k`, `$.seqali[0]` and `$.ali` all fail while `$.plain.k`, `$.plain` and `$.anc` succeed, and of four replace queries the three wrapped ones fail. They are split into two tasks because the fixes differ: anchor and tag need only unwrapping, while an alias needs the document's anchors resolved, which the filter signature does not currently carry. The decoder reads every one of these shapes correctly, which is what makes this a gap in Path rather than a limit of the document, and the repository's own history shows the sibling class was fixed in the decoder alone - commit edee2f9, "handle TagNode in getArrayNode and getMapNode".

Scores, claiming only the 9 swept rows of 30: correctness Medium (PATH-01, PATH-02), architecture None, code quality None, security None, testing None, error handling None, performance None, documentation None, dependency hygiene None, developer experience None, observability not applicable, UX and accessibility not applicable. 21 rows remain unswept - ast, lexer, parser, printer, scanner, token constructors, the Marshal and Unmarshal entry points, Encoder and Decoder methods, the comment API, struct tags and validation, internal/format and cmd/ycat - so every None above claims the swept rows alone and says nothing about the remainder. Closeout has not begun: this audit found Mediums, and it swept 9 rows of 30 rather than the whole project.

Two apparent findings dissolved on investigation and are recorded so a later audit does not re-file them: MapSlice.ToMap leaves a nested MapSlice unconverted, which matches its documented shallow contract and is now pinned as such, and a recursive selector matching nothing returns an empty sequence rather than an error, which is coherent for a multi-valued selector and is likewise pinned.

Learnings: cmd/ycat carries its own go.mod, so it is invisible to `go list ./...` and to the Verify command; sweeping that row means building it from its own module directory. When filtering test output, matching only lines containing `_test.go:` hides the continuation lines of multi-line t.Logf output, which briefly made two working functions look like they returned nothing.

Next: PATH-01, the anchor and tag unwrapping, is the top item.

## iter 7/10 | 67f3ba7a-142257 | 2026-08-08 | PATH-01 | done

Task: PATH-01 (Medium) closed - Path traversal could not reach a value through an anchor definition or a tag.

Changed: path.go (new unexported unwrapNode helper, applied at the head of the eight dispatch and walk functions), .jeffy/probes/path-query (recursive-through-wrapper test added), BACKLOG.md.

Checkpoint: d052b7621440dd16f94475118f640d91f92c175b

Verification: The dispatch sites were enumerated from the code and each was driven by a provoked failure, not assumed: `grep -n 'func (n \*\(selector\|index\|indexAll\|recursive\)Node) \(filter\|replace\)' path.go` returns six methods, plus recursiveNode's filterNode and replaceNode walkers, and unwrapNode is now applied at all eight - `grep -c 'unwrapNode(node)' path.go` returns 8. Acceptance check `go test ./.jeffy/probes/path-wrapper-nodes/ -run 'TestReadThroughAnchorAndTag|TestPlainShapeStillWorks|TestDecoderReadsEveryShape'` exits 0, having exited 1 at the start of this iteration on `$.anc.k`, `$.tagged.k` and `$.seqanc[0]`. Replace through an anchor and through a tag now succeeds too, and the anchor is still present in the document afterwards, which TestPlainShapeStillWorks asserts: unwrapNode returns the inner node itself rather than a copy, so replace mutates in place and the wrapper is untouched. Verify command exits 0 on the first run, `go vet ./...` exits 0, and the battery owning path.go, path-query, exits 0.

The recursive selector was the quiet member of this class and is now pinned with differential evidence. recursiveNode.filterNode switches on node type with no default branch, so an anchored or tagged subtree was skipped in silence rather than reported. Running the new test against the pre-fix path.go, restored with `git show HEAD:path.go` after copying the fix aside, `$..k` returned only "p" and was missing "q" and "r"; against the fixed file it returns all three. A selector that silently returns incomplete results is worse than one that errors, and no existing test covered it.

Contract preserved: unwrapNode only steps past AnchorNode and TagNode, and returns every other node unchanged, so a document without wrappers takes exactly the path it took before - the path-query battery, which reads six known answers and drives IndexAll, Recursive, Replace, Merge, PathBuilder and AnnotateSource, passes unchanged. An alias is deliberately not unwrapped, because resolving one needs the document's anchor definitions that these methods do not carry; that is PATH-02 and its three checks are still red by design. No exported identifier or documented behaviour changed, so no documentation needed updating.

Learnings: To run a new check against unfixed code, copy the fixed file aside and restore the committed one with `git show HEAD:<path>`; `git stash` is the wrong tool because it also removes the new test, which then reports "no tests to run" and reads as a pass.

Next: PATH-02, resolving aliases during Path traversal, is the only open task.

## iter 8/10 | 67f3ba7a-142257 | 2026-08-08 | PATH-02 | done

Task: PATH-02 (Medium) closed - Path traversal could not reach a value through an alias, because resolving one needs the document's anchor definitions and the traversal carried none.

Changed: path.go (new pathCtx carrying an anchor map, newPathCtx and anchorCollector building it from the traversal root, unwrapNode extended to resolve aliases, resolveAliasNode applied where a query terminates on one, and the internal pathNode interface threaded with the context), .jeffy/probes/path-wrapper-nodes (cycle and missing-anchor termination test added, header corrected, `paths` file added now that it is green), BACKLOG.md.

Checkpoint: d8b49137996b7415072cfc1a74b8370d17a9b97a

Verification: `AliasNode.Value` holds the alias name, not the node it refers to, and neither the parser nor the ast package keeps an anchor map, so the map is built per traversal by walking the root with ast.Walk. The internal interface was threaded rather than a package-level map used, because a *Path is reusable and per-call state on it would race. The change is confined to path.go: `grep -rn '\.filter(\|\.replace(' --include='*.go'` outside path.go returns nothing, so no caller outside the file sees the new signature. Acceptance check `go test ./.jeffy/probes/path-wrapper-nodes/` exits 0 in full, having exited 1 at the start of this iteration on `$.ali.k`, `$.seqali[0]`, `$.ali` and Replace of `$.ali.k`. Verify command exits 0, `go vet ./...` exits 0, and all 10 batteries are green.

Two claims in the new code were checked by execution rather than asserted. Termination: a self-referential alias `a: &x *x`, a mutual chain `a: &x *y` with `b: &y *x`, and a missing anchor `a: *nosuch` each return an ordinary error within a five-second bound rather than spinning, which the new test enforces with a timeout so a regression hangs the check instead of passing it. Terminal resolution: a query landing on an alias returns the anchored node, because `Path.Read` unmarshals the fragment the query returns and a bare `*a` means nothing once lifted out of the document that defines its anchor - that was the last failing case and it needed resolveAliasNode at the four terminal returns, not just the dispatch unwrap.

Contract preserved: unwrapNode returns every non-wrapper node unchanged, and an alias whose anchor is not reachable from the traversal root is returned unresolved so the caller reports the same invalid-query error as before rather than guessing. The path-query battery, which pins six known answers plus IndexAll, Recursive, Replace, Merge, PathBuilder and AnnotateSource, passes unchanged. pathNode and its methods are unexported, so no public signature changed and no documentation needed updating. One consequence is worth naming for the next run: an alias resolves to the shared anchored node, so replacing through an alias edits the value every other alias to it also sees.

Learnings: When a traversal needs document-wide context, thread it through the internal interface rather than storing it on the reusable public value; a *Path can be used from more than one goroutine and per-call state on it would be a race. A termination claim is only tested if the check fails on non-termination, which means a timeout, not a plain call.

Next: the ledger is empty. Two iterations remain, so iteration 9 sweeps unswept Surface inventory rows and iteration 10 writes the handoff.

## iter 9/10 | 67f3ba7a-142257 | 2026-08-08 | AUDIT | audit

Task: Replenishing audit on an empty ledger. Swept six more Surface inventory rows with a new known-answer battery and filed what the sweep found.

Changed: .jeffy/probes/struct-and-convert (new green battery, with paths file), .jeffy/probes/node-value-roundtrip (new red repro battery, no paths file yet), PLAN.md (six rows flipped to swept), BACKLOG.md (NODE-01).

Checkpoint: 4d5c9382527ebaf03d9ec55a708250ba311ffbe8

Verification: Rows swept this iteration: Marshal entry points, Unmarshal entry points, marshaler and unmarshaler interfaces, encoder struct and tag handling, decoder type conversion, and struct tag parsing and validation. That is 15 of 30 rows swept, up from 9. Verify command exits 0, `go vet ./...` exits 0, and all 12 batteries were run: 11 green and only node-value-roundtrip red, which is the repro for the finding below.

Finding: NODE-01, High. `yaml.ValueToNode` followed by `yaml.NodeToValue` returns a different string than it was given, with literal quote characters embedded in the value. Encoder.encodeString quotes a value by rewriting the string itself and then builds the token from the already-quoted text, so a StringNode's Value carries the quotes; rendering the node and re-parsing it is correct because the parser unquotes, but NodeToValue reads Value directly and hands the quotes back as data. The enumeration was produced by running a corpus rather than by reading the encoder: 16 of 18 strings are corrupted, and the 16 are exactly those the encoder must quote, while the 2 plain ones survive. Decoder.DecodeFromNode inherits it, which the battery also pins. This predates the run, verified by running the same corpus in a detached worktree at the run's base commit edee2f91616c6d73112a13e7c0dbde72ce938877, where the same 16 of 18 fail; the encode-side quoting this run changed in iterations 2 and 4 is not the cause, and the text path Marshal then Unmarshal is correct throughout.

Scores, claiming only the 15 swept rows of 30: correctness High (NODE-01), architecture None, code quality None, security None, testing None, error handling None, performance None, documentation None, dependency hygiene None, developer experience None, observability not applicable, UX and accessibility not applicable. 15 rows remain unswept - ast constructors, ast rendering, ast traversal and merge, lexer, parser entry points, parser token grouping, printer, scanner, token constructors, the comment API, Encoder methods, Decoder methods, decoder anchor and reference sources, internal/format and cmd/ycat - so every None above claims the swept rows alone. Closeout has not begun: this audit found a High.

One observation examined and cleared, recorded so a later audit does not re-file it: a []byte field encodes as a sequence of byte numbers rather than a base64 string or a !!binary tag, which differs from encoding/json and from gopkg.in/yaml.v3. It round trips correctly within this library, and the README's "Respects encoding/json behavior" claim is scoped by its own sub-bullets to json tags and the Marshaler and Unmarshaler interfaces, so no documented contract is broken.

Learnings: To prove a defect predates the run, add a detached worktree at the base commit and run the corpus there; it needs no changes to the working tree and cannot disturb uncommitted work. Prefer `git worktree add` to a unique directory over removing and recreating one.

Next: NODE-01 is the only open task and the top item for the next run. This is the final iteration of budget, so iteration 10 writes the handoff rather than starting it.

## iter 10/10 | 67f3ba7a-142257 | 2026-08-08 | WRAPUP | done

Task: Final iteration of the budget. Tidied BACKLOG.md, recorded the two classes this run settled, and wrote the handoff. NODE-01 was not started: fixing it means changing where the encoder puts a quoted value - today encodeString rewrites the string and builds the token from the quoted text - which touches the encode and ast boundary that three of this run's fixes already sit on, and a change that size cannot be verified inside a final iteration.

Changed: BACKLOG.md (Next section spacing, two Settled classes recorded), JOURNAL.md.

Checkpoint: 70a08d162705a2a467a6196dabf57f7710eb81b8

Verification: Verify command exits 0, `go vet ./...` exits 0, and 11 of the 12 batteries are green; node-value-roundtrip is red and is the repro for NODE-01, the one open task. No Surface inventory row is stale: the last commit to touch each library file precedes or equals the sweep hash recorded for the rows covering it - encode.go and option.go at b40d192 against sweeps at 05ca010 and 4d5c938, decode.go at b2ad02b against 05ca010, path.go at d8b4913 which is the Path rows' own sweep hash, and yaml.go, struct.go, validate.go, error.go and token/token.go unchanged since before the run. The two Settled classes lines carry enumerating commands whose real output was re-run while writing them: `grep -c '^\tnode = unwrapNode(ctx, node)$' path.go` returns 8, one per dispatch and walk site, with a ninth call inside resolveAliasNode - the first form of that line claimed 8 for a command that returns 9 and was corrected before the checkpoint.

Stall check: this iteration changed only BACKLOG.md and JOURNAL.md and moved no BACKLOG item between states, so it is a no-progress iteration by the letter. It is a WRAPUP, which the ceremony exemption covers, and the previous primary entry was an AUDIT that filed a finding, so no blocking pair is formed.

Handoff for the next run. Start with NODE-01, the only open task and the run's one High: ValueToNode followed by NodeToValue embeds literal quote characters in any string the encoder must quote, 16 of 18 in the committed corpus, and DecodeFromNode inherits it. The repro is committed and red at .jeffy/probes/node-value-roundtrip; give it a paths file once green. The likely shape of the fix is to keep the unquoted value on the StringNode and let the node's String method apply quoting, which is where ast.escapeSingleQuote already lives, rather than pre-quoting into the token; check the encode-options, scalar-roundtrip and single-quote-escapes batteries as that boundary moves, since all three pin it.

After NODE-01, 15 of 30 inventory rows remain unswept and they are the ones a fresh run should sweep next: ast constructors, ast rendering, ast traversal and merge, lexer, parser entry points, parser token grouping, printer, scanner, token constructors, the comment API, Encoder methods, Decoder methods, decoder anchor and reference sources, internal/format, and cmd/ycat. cmd/ycat needs building from its own module directory because it carries its own go.mod and is invisible to `go list ./...`. Two observations are recorded for the ledger rather than filed: replacing through an alias now edits the shared anchored value every other alias to it also sees, and a []byte field encodes as a sequence of byte numbers rather than base64 or !!binary.

Convergence was not reached and was not reachable: it requires no unswept row, and the surface is 30 rows against a 10-iteration budget of which one was the first audit. The state files carry the position forward, so the next run resumes at 15 of 30 with the batteries as its instruments rather than rebuilding them.

Learnings: State an enumerating command's output only after running that exact command; a count taken from a slightly different pattern is how a state file acquires a number nobody can reproduce.

Next: relaunch in a fresh session. NODE-01 first, then sweep the 15 remaining rows.

## iter 1/10 | 373a1ae5-153329 | 2026-08-08 | NODE-01 | done

Task: NODE-01 (High) closed as a class, not an instance - a scalar node the encoder builds carried the value's quoted rendering instead of the value, so every consumer reading the node rather than its text got the quote characters back as data.

Changed: encode.go (new quotedString helper; encodeString, encodeTime and encodeDuration now build quoted-scalar tokens), .jeffy/probes/node-value-roundtrip (single quote, JSON time and duration, rendered-text and class-enumeration tests added, the nil decoder reader corrected, `paths` file added now that it is green), BACKLOG.md.

Checkpoint: a4659e629f9f54edef5b5e95b0b74485cd40e4fa

Verification: The filed reproduction ran first and reproduced, and it reproduced wider than the finding described. `token.New(v, v, pos)` takes the token's value and its origin, and encodeString passed the already-quoted text as both, so `ast.String` copied the quotes into `StringNode.Value`. Parsing `k: "true"` for contrast returns Value "true" with token type DoubleQuote and origin ` "true"`, which is the contract the encoder now matches: raw value on the token, quoted rendering in the origin, quote style in the token type, and `ast.StringNode.String` re-applying it at render time. Acceptance check `go test ./.jeffy/probes/node-value-roundtrip/` exits 0, having exited 1 at the start of this iteration.

The class had three sites, and the third was found by running rather than by reading the finding. Under the JSON style encodeTime and encodeDuration pre-quoted through the same idiom, and there the failure was silent: `yaml.NodeToValue` on a struct holding a time.Time and a time.Duration returned a nil error with both fields zero, which no liveness probe would catch. The enumeration is executed, not grepped: TestEveryScalarSiteHoldsItsValue encodes a value of every scalar kind the encoder emits - string, quoted string, bool, int, uint, float, both infinities, NaN, nil pointer, time, duration, anchor and alias - in four styling modes, walks the produced tree, and asserts each scalar node agrees with what the parser makes of that node's own text. Against the unfixed encode.go it reports 22 corrupted nodes across the four modes and names surface the finding never mentioned: under the JSON style every mapping key was corrupted too, along with the anchor and alias values. The structural companion reconciles: `grep -c 'ast\.\(String\|Bool\|Integer\|Float\|Null\|Infinity\|Nan\)(token\.' encode.go` returns 20 scalar constructions, 16 of which pass the raw value as both value and origin and 4 of which build quoted-scalar tokens.

Contract preserved, checked differentially rather than argued. TestRenderedTextUnchangedByNodeShape asserts that for every corpus value in four styling modes the node's text is byte-identical to what Marshal writes, and it passes both before and after the change, so the rendered document did not move; TestTextPathIsCorrect likewise passes on both sides. That pairing is the evidence: the four tests that detect the defect fail on the unfixed code and pass on the fixed code, and the two that pin the contract pass on both. encodeTime and encodeDuration are deliberately double-quoted rather than routed through quotedString, because quotedString honours the single quote option and would emit single quotes inside JSON output, which is a byte change and not this task's business. The public consequence worth recording under the interfaces constraint: `ast.StringNode.Value` for an encoder-built quoted scalar now holds the raw string where it previously held the quoted text. That is the defect itself rather than a contract, no test in the suite asserted the old shape, and no documentation described it - `grep -rn 'ValueToNode\|NodeToValue\|EncodeToNode' --include='*.md'` returns only one CHANGELOG line announcing the function's existence - so nothing needed rewording alongside the fix.

Verify command exits 0 in both parts, `go vet ./...` exits 0, and all 12 batteries exit 0, which is the first iteration in this project's record with none red; node-value-roundtrip was the standing red and now owns a `paths` file naming encode.go, ast/ast.go, token/token.go, yaml.go and decode.go, so it gates those files from here.

One observation examined and cleared rather than filed, so a later audit does not re-open it: the battery previously built its decoder with `yaml.NewDecoder(nil)`, which panics inside decodeInit when io.Copy reads the nil reader. That is the battery's defect and not the library's - `yaml.NodeToValue` itself passes an empty `bytes.Buffer`, encoding/json panics the same way on `json.NewDecoder(nil).Decode`, and a nil io.Reader is a programming error on a user-error class surface. The battery now passes an empty reader, matching the library's own idiom.

Learnings: A defect in how a value is stored, rather than in how it is rendered, hides behind every text-level test, because the render path and the read path disagree only when a consumer skips the render. When a fix must not move output, prove it with a check that passes on both sides of the fix and pair it with checks that fail on only one - a suite where everything flips tells you the behaviour changed but not that it changed only where intended.

Next: the ledger is empty and nine iterations remain, so iteration 2 audits, sweeping the unswept Surface inventory rows breadth-first.

## iter 2/10 | 373a1ae5-153329 | 2026-08-08 | AUDIT | audit

Task: Full audit on an empty ledger, sweeping the fifteen remaining Surface inventory rows breadth-first and filing what the sweep found.

Changed: .jeffy/probes/broad-sweep (new green battery covering the lower layers and the remaining public API rows, with a paths file), .jeffy/probes/context-cancellation (new green battery pinning the context semantics, with a paths file), .jeffy/probes/ast-entry-render and .jeffy/probes/ycat-cli (new red repro batteries, no paths files yet), PLAN.md (fifteen rows flipped to swept), BACKLOG.md (AST-01, YCAT-01, CTX-01, AST-02, FMT-01).

Checkpoint: af9d31fe41b12dd28292d9b48b9fb5a104b42e7b

Verification: Every row was swept with known answers rather than liveness probes - hand-computed token lists and positions for the lexer, a token-type table for the classifier, an idempotency check for rendering, counted results for the traversal filters including the empty side, byte-exact renderings for the constructors. The three parser entry points are driven against each other, ParseComments and AllowDuplicateMapKey at both values, the printer's isColored at both values, RecursiveDir at both values, and all three comment positions asserted to place their text differently. The scanner is checked against the lexer token for token, and the cmd/ycat row is swept by building the real binary from its own module directory and running it, because a CLI's contract with a shell is its exit status and its stream discipline rather than anything a unit test sees.

Rows swept this iteration: Encoder methods, Decoder methods, decoder anchor and reference sources, comment API, ast constructors, ast rendering, ast traversal and merge, lexer, parser entry points and modes, parser token grouping, printer, scanner, token constructors and Token methods, internal/format, and cmd/ycat. That is 30 of 30 rows swept, up from 15, so these scores claim the whole mapped surface for the first time in this project's record. Three coverage gaps found while writing the claims were closed rather than glossed: ParseFile, the TokenGroup accessors and Tokens.InvalidToken were named by their rows but not driven, and each now is.

Verify command exits 0 in both parts, `go vet ./...` exits 0, and 14 of the 16 batteries exit 0; ast-entry-render and ycat-cli are red and are the repros for AST-01 and YCAT-01. Before scoring Testing, six packages plus the root package were run in isolation and the root package again under `-shuffle=on`, all exiting 0, so no order dependence or leaked state is hiding behind the whole-suite run.

Findings. AST-01, Medium: `ast.SequenceEntryNode.String` returns the empty string behind a `// TODO` and `MarshalYAML` returns those bytes with a nil error; the parser builds one of these per element at both sequence paths and stores them in the exported `SequenceNode.Entries`, so a caller rendering entries gets silence. Reproduced on block, flow and mapping-element sequences. YCAT-01, Medium: the CLI exits 0 on every failure and writes errors to stdout, reproduced against the built binary for a missing operand and a missing file. CTX-01, Medium: the four exported context entry points never observe cancellation while their doc comments say only "with context.Context"; all four complete on a context cancelled before the call and neither encode.go nor decode.go contains a single cancellation check. AST-02, Low: `CommentGroupNode.Type` returns `CommentType`, so the exported `CommentGroupType` constant never matches and Filter on it silently returns nothing. FMT-01, Low: `internal/format.FormatFile` has no caller anywhere in the module.

Scores, claiming all 30 swept rows: correctness Medium (AST-01), error handling Medium (YCAT-01), documentation Medium (CTX-01), UX Medium (YCAT-01, the only user-facing surface), testing Medium, code quality Low (AST-02, FMT-01), architecture None, security None, performance None, dependency hygiene None, developer experience None, observability not applicable, accessibility not applicable. Testing is scored by the gap that let AST-01 ship - nothing exercised entry rendering - and files no separate task, because the fix for AST-01 carries its own regression battery. Closeout has not begun: this audit found Mediums.

Two candidate findings were examined and cleared rather than filed. The first is alias expansion: a doubling bomb of nine branches over six levels decodes in about a millisecond because an alias resolves to the shared anchored node rather than a copy, so there is no exponential amplification behind the missing cancellation checks, which is what keeps CTX-01 a documentation finding rather than a denial-of-service one. The second is `ast.SequenceMergeValueNode`, which is exported but implements only `MapRange` and is not an `ast.Node`; that is the deliberate adapter its comment describes, and its iteration yields the keys it is given.

Learnings: A sweep claim is only as good as its enumeration, and writing the claim is what exposes the gap - three functions named by their rows had no probe until the row text was being written, which is an argument for drafting the sentence before believing the battery. When a probe disagrees with the code, find out which is wrong before filing: of the seven disagreements this iteration, four were the probe's error - the scanner's io.EOF drain signal, FormatFile's missing trailing newline, SequenceMergeValueNode's interface, and the shape of the grouped token tree - and only three were the library's.

Next: AST-01 is the top item, then YCAT-01 and CTX-01, then the two Lows.

## iter 3/10 | 373a1ae5-153329 | 2026-08-08 | AST-01 | done

Task: AST-01 (Medium) closed - `ast.SequenceEntryNode.String` was a stub returning the empty string behind a `// TODO`, so every caller reading the exported `SequenceNode.Entries` got nothing, and `MarshalYAML` handed back those same empty bytes with a nil error.

Changed: ast/ast.go (the multi-line re-indentation inside `blockStyleString` extracted as `sequenceEntryValueString`; `SequenceEntryNode.String` implemented on top of it), .jeffy/probes/ast-entry-render (rendering contract, comment ownership, sequence agreement and nil-value tests added, `paths` file added now that it is green), BACKLOG.md.

Checkpoint: 1794aa963cf33f9f463cc42c595a0c6ae92a604a

Verification: The filed reproduction ran first and reproduced on all three sequence shapes. The fix renders an entry through the same code the sequence uses for that entry's line rather than a second implementation: the re-indentation block was lifted out of `blockStyleString` verbatim and both now call it, which is what `TestEntryAgreesWithSequenceRendering` enforces by requiring each entry's first rendered line to appear in the sequence's own rendering across five shapes including a literal block and a nested sequence. Acceptance check `go test ./.jeffy/probes/ast-entry-render/` exits 0, having exited 1 at the start of this iteration.

Contract preserved, proved by execution rather than by argument. A 15-shape sequence corpus - block at two indentations, mapping elements, literal and folded blocks, a quoted multi-line string, nested sequences, head and line comments, flow style, an empty element, anchor and alias, a tag, and a doubly nested mapping - was rendered under the committed ast.go and under the fixed one, and the two outputs are byte-identical; the extraction moved no output, and the only behaviour that changed is that entry rendering returns content instead of "". That differential was re-run after the second change to the implementation, not only after the first. Verify command exits 0 in both parts, `go vet ./...` exits 0, and 15 of 16 batteries exit 0 with only ycat-cli red, which is YCAT-01's repro.

The flow and block distinction was derived from the parser rather than guessed. `grep -n 'ast.SequenceEntry(' parser/parser.go` returns the two construction sites, and reading them shows what goes into `Start`: a block entry gets its dash, a flow entry gets the "," that precedes it, and the first flow entry gets nothing at all because `Token.RawToken` returns nil for a nil receiver. So a flow entry renders as its value alone - the brackets and separators belong to the sequence - and every other entry renders as its dash, its indentation and its value. The first attempt tested `Start.Type != SequenceEntryType` and lumped everything unrecognised into the flow case, which made an entry built with `token.New("-", ...)` render bare, because `token.New` classifies "-" as a plain string; testing for the two shapes the parser actually produces, a nil Start or a CollectEntry token, is both narrower and right.

Public behaviour changed and is recorded here per the Constraints: `SequenceEntryNode.String` and `MarshalYAML` now return the entry's text where they returned "" and empty bytes. No test in the suite pinned the old values and no documentation described them, so nothing needed rewording; the method's own doc comment was rewritten to state the block and flow contract it now implements.

One finding was discovered while doing this work and is filed rather than fixed, because it is a different method with a different cause: AST-03, Medium. `SequenceEntryNode.Start` is not maintained. It is nil for the first entry of every flow sequence, so `Entries[0].GetToken()` on `[1, 2]` returns nil and a caller reading its Position panics; and `SequenceNode.AddColumn` shifts the sequence's own tokens and its values but never its entries, so after `seq.AddColumn(2)` on a two-element block sequence entry 0 moves only because its Start aliases the sequence's start token while entry 1 stays at column 1. Both were reproduced. The second only became observable once String returned content, which is the ordinary consequence of finishing a stub.

Two things were examined and cleared rather than filed. The precedence in `len(splittedValues) > 1 && value.Type() == StringType || value.Type() == LiteralType` reads as a mistake but is not one in effect: it groups as `(len > 1 && String) || Literal`, and when the type is Literal with a single line the loop it guards has no iterations, so no output differs either way; it was copied verbatim into the extracted helper rather than tidied, because changing it is not this task. And `SequenceEntryNode.AddColumn` shifting only `Start` and not `Value` is not a double-shift bug waiting to happen: `Entries[i].Value` and `Values[i]` are the same pointer, verified by comparison, so the sequence's own AddColumn already moves the value.

Learnings: When a node type is reached by two construction paths, read both before choosing the predicate that tells them apart - the difference here was not the node's type but which token the parser had available to give it, and only one of the two paths had one at all. A test that builds a token with the general constructor is not building the token the parser builds; `token.New` classifies by value, so `token.New("-", ...)` is a string token and not a sequence entry token.

Next: YCAT-01 is the top item, then CTX-01 and AST-03, then the two Lows.

## iter 4/10 | 373a1ae5-153329 | 2026-08-08 | AST-03 | done

Task: AST-03 (Medium) closed - `ast.SequenceEntryNode.Start` was not maintained, so `GetToken` returned nil for the first entry of every flow sequence and `SequenceNode.AddColumn` left every entry after the first at its old indentation.

Changed: ast/ast.go (`SequenceEntryNode.GetToken` falls back to the value's token when there is no Start; `SequenceNode.AddColumn` now shifts the entries' start tokens, skipping the one it has already moved), .jeffy/probes/ast-entry-token (new battery, `paths` file added now that it is green), BACKLOG.md.

Checkpoint: a066e9488cb9e7f899564fd48907e8c42af22e21

Verification: The filed reproduction ran first and reproduced both consequences, the second across three sequence shapes at two shift values, and the first as an actual panic rather than a nil return - `reading the first flow entry's position panicked: runtime error: invalid memory address or nil pointer dereference`. Acceptance check `go test ./.jeffy/probes/ast-entry-token/` exits 0, having exited 1 at the start of this iteration.

The aliasing the fix turns on was established by pointer comparison rather than inferred from behaviour, because a shift that looks right can be two errors cancelling. Printing the addresses shows a block sequence hands its own start token to its first entry - `Entries[0].Start == seq.Start` is true for `- one\n- two\n- three\n` and for the indented form, and false for entries 1 and 2 - while a flow sequence gives entry 0 nothing at all and entries 1 upward the "," tokens, which alias neither Start nor End. `Entries[i].Value == Values[i]` holds in every shape. So `AddColumn` shifts each entry's start token except the one that is the sequence's own, which the existing lines have already moved; without that guard the first entry would travel twice as far as its siblings, which is the same defect wearing the opposite sign.

Contract preserved: the 15-shape rendering corpus is byte-identical under the committed ast.go and the fixed one, because nothing changes for a document that is never shifted - the new behaviour appears only after `AddColumn`, and `GetToken` differs only where it previously returned nil. Verify command exits 0 in both parts, `go vet ./...` exits 0, and 16 of 17 batteries exit 0 with only ycat-cli red, which is YCAT-01's repro. The reversibility check is new and deliberate: shifting a sequence by 3 and back by 3 must restore both the sequence's rendering and every entry's, which a fix that shifted the shared token twice would fail.

One thing was examined and cleared rather than filed, recorded so a later audit does not re-open it. `SequenceEntryNode.AddColumn` carries the boilerplate comment "add column number to child nodes recursively" while shifting only its own start token, which reads like a defect. It is not one in effect: after `entry.AddColumn(4)` on `- a: 1\n  b: 2` the entry renders `    - a: 1\n      b: 2`, correctly indented, because the entry re-indents its value from its own column rather than from the value's. Only the value node's internal column is left stale, and no rendering path reads it for that purpose. The comment is the same boilerplate on every AddColumn method in the file, so filing it would be ledger churn against correct behaviour.

Learnings: When a fix walks a collection whose members may share pointers with the container, establish the sharing by comparing addresses before writing the loop; here the first entry's start token is the sequence's own, and a loop written from the behaviour alone would have double-shifted it while still looking plausible on a single-element document. A reversibility check is the cheap way to catch a double-shift, because moving twice and back once leaves a residue that a one-directional assertion cannot see.

Next: YCAT-01 is the top item, then CTX-01, then the two Lows.
# Journal

Append-only. One primary entry per iteration; SALVAGE and ROTATION entries are additional. Never rewrite past entries (filling the current entry's Checkpoint field is completion, not a rewrite).

Heading grammar, exactly (fenced and indented here so this example is never mistaken for an entry by anything that counts or rotates them):

```
  ## iter <i>/<N> | <run-id> | <YYYY-MM-DD> | <task-id or AUDIT or EVALUATOR or RATCHET or WRAPUP or SALVAGE or ROTATION> | <done|blocked|audit|converged|salvage|rotation>
```

Write a real heading at column zero, never indented: the indentation above belongs to the example alone, and an indented heading is invisible to the rotation anchor and to the archive counter, so the entry under it is not counted and not rotated.

SALVAGE entries take status salvage; ROTATION entries take status rotation. An EVALUATOR entry records an evaluator-gate iteration: status audit when the run continues after the verdict, blocked on a terminal second REJECT, converged when that same iteration declares.

run-id is the first 8 characters of the session id, a hyphen, then the HHMMSS of started_at from the loop state frontmatter, so two runs in one session are told apart. Body fields, in order: Task, Changed, Checkpoint (the jeffy checkpoint commit hash, or none with the reason), Verification, Learnings, Next.

The closing entry that declares convergence carries the evaluator verdict in its Verification field: `Evaluator: PASS - <one-line summary>`, or `Evaluator: unavailable (<reason>)`. An earlier EVALUATOR entry records its own verdict the same way and never stands in for the closing one: the Stop hook reads the closing entry alone, so a run that gates early and keeps working re-invokes the gate at the declaration.

Closed tasks are recorded here as one line each (ID, title, closing evidence), because BACKLOG.md deletes them. Rotation: when this file exceeds 500 lines, move all but the last 10 entries to the end of JOURNAL-archive.md, appending to whatever that file already holds and never overwriting it, because the archive accumulates across every rotation and every run; create it only when it does not already exist, and record the rotation as a ROTATION entry.

## iter 5/10 | 373a1ae5-153329 | 2026-08-08 | YCAT-01 | done

Task: YCAT-01 (Medium) closed - `cmd/ycat` exited 0 on every failure and wrote its error text to stdout, so a shell could not tell a failure from an empty document and a redirected render captured the error message as if it were output.

Changed: cmd/ycat/ycat.go (errors now go to stderr and set a failing exit status), .jeffy/probes/ycat-cli (`paths` file added now that it is green), BACKLOG.md.

Checkpoint: 511aac77786c9cc6ec996baa19d9b55b65ebfc20

Verification: The filed reproduction ran first and reproduced both halves on the built binary. Acceptance check `go test ./.jeffy/probes/ycat-cli/` exits 0, having exited 1 at the start of this iteration. The contract the finding was actually about is a shell contract, so it was checked in a shell rather than only through the battery: with no operand and with a missing file the binary now exits 1, writes the message to stderr and leaves stdout empty; on a valid file it exits 0, writes nothing to stderr and renders the numbered document. `ycat nosuch.yaml && echo next` no longer runs the next command, `ycat ok.yaml && echo next` still does, and redirecting stdout on the failing call now captures 0 bytes where it previously captured the error text.

Contract preserved: the message itself is unchanged. `yaml.FormatError` returns `e.Error()` for anything that is not a yaml.Error, which both failure paths are, so moving the write from `fmt.Printf` to `fmt.Fprintf(os.Stderr, ...)` changes the stream and the status and nothing else; the success path never touched this branch and is byte-identical, which the battery's success-path assertions pin. Verify command exits 0 in both parts, `go vet ./...` exits 0 in the root module and in cmd/ycat's own module, and all 17 batteries exit 0 - the first iteration this run with no red battery at all.

The colour flags were deliberately left alone. `FormatError(err, true, true)` writes ANSI sequences to stderr whether or not stderr is a terminal, which is worth a look on its own, but it is not what YCAT-01 names and changing it would alter the message this fix is claiming to preserve.

Learnings: `cmd/ycat` is a separate module with its own go.mod, so `go test ./...` and the Verify command never see it; it has to be built and vetted from its own directory, which is also why a defect this plain survived every green gate. A CLI's contract with a shell is its exit status and its stream discipline, and neither is visible to a test that only inspects printed text - the check has to run the binary and read `$?`.

Next: CTX-01 is the top item, then the two Lows.

## iter 6/10 | 373a1ae5-153329 | 2026-08-08 | CTX-01 | done

Task: CTX-01 (Medium) closed - the exported entry points that take a context.Context said only "with context.Context", which a Go caller reads as cancellable, while none of them observes cancellation. The context's real job is carrying values to the context-taking marshaler and unmarshaler interfaces, and the doc comments now say exactly that.

Changed: yaml.go, encode.go, decode.go (doc comments on the six exported context entry points), .jeffy/probes/context-cancellation (all six now driven, the doc contract checked against the package AST, header corrected), BACKLOG.md.

Checkpoint: dd5f4f0aa2a356989b733d1a94d61a3b9f713895

Verification: The filed finding said four entry points. It was wrong: `grep -n '^func [A-Z].*ctx context\.Context\|^func ([a-z] \*[A-Z][A-Za-z]*) [A-Z].*ctx context\.Context' *.go` returns six, and the two the finding missed - `Encoder.EncodeToNodeContext` and `Decoder.DecodeFromNodeContext` - ignore cancellation exactly as the other four do, which was confirmed by calling all six with a context cancelled before the call and watching every one return a nil error and its ordinary result. Documenting four of six would have left the claim as wrong as it started.

The acceptance check is computed rather than typed, because a hand-written list is precisely what under-counted this finding. `TestEveryContextEntryPointDocumentsItsContract` parses the package with go/parser, selects every exported function or method whose parameters include a context.Context, and asserts each one's doc comment states both what the context is carried to and that it is not checked for cancellation; it then asserts the discovered set equals the six by name, so adding a seventh entry point fails the check until its documentation follows. Run against the committed doc comments the check fails on all six with both assertions; against the fixed ones it passes. That differential was run by restoring the three files from HEAD and re-running the same battery.

Contract preserved, and this one is provable rather than argued: the change is comment-only. `git diff --numstat yaml.go encode.go decode.go` reports 8 added and 0 deleted lines in each file, and filtering the added lines for anything that is not a comment returns 0. No behaviour moved, so no Surface inventory row went stale - a row is stale when its implementing code changes, and no implementing line did. Verify command exits 0 in both parts, `go vet ./...` exits 0, and all 17 batteries exit 0.

Documenting rather than implementing cancellation was the deliberate choice, recorded here because the opposite is the tempting one. Adding `ctx.Err()` checks would change public behaviour for every existing caller that passes a context it later cancels, on a library at v1, in exchange for bounding work that is already bounded: the audit established that alias expansion resolves to the shared anchored node rather than a copy, so there is no amplification for a timeout to protect against, and `maxDecodeDepth` already caps recursion. The honest fix for a doc that misleads is a doc that does not.

Learnings: A finding's own enumeration is a claim like any other and rots the same way - CTX-01 counted four entry points and there were six, so the fix had to re-derive the set before it could satisfy the finding. When a task's acceptance is "every X does Y", compute X from the source inside the check rather than listing X in the check, so the check keeps working when the set grows.

Next: AST-02 and FMT-01, the two Lows, are all that remain on the ledger.

## iter 7/10 | 373a1ae5-153329 | 2026-08-08 | AST-02 | done

Task: AST-02 (Low) closed as Declined - its proposed fix is a regression. `ast.CommentGroupNode.Type` reporting `CommentType` rather than `CommentGroupType` is load-bearing rather than an oversight, and the hazard the finding actually names was closed by documenting the two constants instead.

Changed: ast/ast.go (doc comments on the CommentType and CommentGroupType constants), .jeffy/probes/broad-sweep (the note that pinned the behaviour now records why it is settled), BACKLOG.md (AST-02 moved to Declined).

Checkpoint: 55382833766ad006a2dad35f54d0b32f8bf94153

Verification: The finding was re-verified as still real before anything else - `Filter(CommentGroupType)` returns 0 where `Filter(CommentType)` returns 1 on a commented document. Then the filed fix was tried rather than reasoned about: changing `CommentGroupNode.Type` to return `CommentGroupType` makes `go test ./...` exit 1 with `TestNodePath` failing in the parser package, which collects comment paths by filtering walked nodes on `ast.CommentType`. Walking a commented document confirms why: `ast.Walk` visits `*ast.CommentGroupNode` and never a bare `*ast.CommentNode`, so `CommentType` is the only type a traversal can filter on to find comments at all, and the acceptance check as filed - make `Filter(CommentGroupType)` find the group - cannot be satisfied without silently emptying every caller that collects comments that way, the project's own test included. The experiment was reverted and the parser package re-run to 0 before proceeding.

That makes this a genuine not-worth-fixing, not deferred work: the change is available, cheap and wrong. What remains true is the hazard a caller meets - writing `Filter(ast.CommentGroupType, node)` and getting nothing back with no signal - and that is closed without touching behaviour by documenting both constants: CommentType now records that group nodes report it too and that Walk visits the group rather than its contents, and CommentGroupType records that no node returns it and that CommentType is what to filter on.

Contract preserved, provably: `git diff --numstat ast/ast.go` reports 11 added and 2 deleted lines, the 2 deletions being the two one-line comments replaced, and filtering the added lines for anything that is not a comment returns 0. Verify command exits 0 in both parts, `go vet ./...` exits 0, and all 17 batteries exit 0. No Surface inventory row went stale, because no implementing line changed.

Learnings: Try the filed fix before arguing about it - AST-02 read like a one-word change and the one word was load-bearing, which twenty minutes of reading the constant would not have settled and one test run did. When a finding names a real hazard but its proposed remedy is a regression, the decline is not the end of the work: the hazard can usually be closed on a different axis, and documenting the surprising invariant is both cheaper and more durable than changing it.

Next: FMT-01, the last open item, then the convergence sequence.

## iter 8/10 | 373a1ae5-153329 | 2026-08-08 | FMT-01 | done

Task: FMT-01 (Low) closed - `internal/format.FormatFile` had no caller anywhere in the module, so nothing could reach it. Deleted, along with the two helpers that existed only to serve it.

Changed: internal/format/format.go (FormatFile, the unexported formatFile method and hasCommentFile removed), .jeffy/probes/broad-sweep (the note explaining why FormatFile was left unexercised replaced by what the package exports now), PLAN.md (internal/format row), BACKLOG.md.

Checkpoint: a64462df849041d90f6b2b2d6d64d1a7cebfad74

Verification: The finding was re-verified before the fix - `grep -rn 'FormatFile' --include='*.go' .` returned the definition and nothing else outside `.jeffy/`. The deletion was scoped by following the reachability rather than by deleting the one named function: `formatFile` and `hasCommentFile` were each referenced from exactly two places, their own definition and FormatFile's single call, so removing FormatFile alone would have left two more unreachable functions behind. All three went. The acceptance check now returns no match outside `.jeffy/`, and `grep -rn '\bformatFile\b\|\bhasCommentFile\b'` returns none either.

The internal package is module-private but its reachability was checked across the whole tree rather than assumed from the package name, because Go's internal rule is a path prefix rather than a module boundary and `cmd/ycat` sits under that prefix in its own module: the grep covered cmd/ycat and testdata as well as the library, and found no importer. What survives is the two functions decode.go actually calls, `FormatNode` and `FormatNodeWithResolvedAlias`, which `grep -n '^func [A-Z]' internal/format/format.go` now returns in full.

Contract preserved: `git diff --numstat internal/format/format.go` reports 0 added and 31 deleted lines, so nothing was rewritten and only unreachable code left. Verify command exits 0 in both parts, `go build ./...` exits 0, `go vet ./...` exits 0, and all 17 batteries exit 0. No Surface inventory row went stale in the sense that matters - the internal/format row was re-stated because the surface it describes shrank, and its battery still drives every function the package exports.

The ledger is now empty: every finding this run filed is completed or, in AST-02's case, declined with its reason recorded. Nothing is left as a silent Low.

Learnings: A dead function is usually the root of a dead subtree, so trace what it alone calls before deleting it - deleting FormatFile by itself would have swapped one unreachable function for two. Go's internal package rule is a path prefix, not a module boundary, so a sibling module under the same prefix can import an internal package; check reachability across the tree rather than reasoning from the directory name.

Next: the ledger is empty and the run has a clean full audit on record, so iteration 9 runs the adversarial evaluator gate and, if it passes and the closing conditions hold, declares convergence in that same iteration.

## iter 9/10 | 373a1ae5-153329 | 2026-08-08 | EVALUATOR | audit

Task: Adversarial evaluator gate on an empty ledger. Verdict REJECT, with one substantiated High. Filed it and two Low observations; the run does not converge.

Changed: .jeffy/evaluator/373a1ae5-153329.md (the gate's artifact), BACKLOG.md (EVAL-01, EVAL-02, EVAL-03).

Checkpoint: 97ea55ca28eb4d2d122c9671a7c731df922812d3

Verification: Evaluator: REJECT - the NODE-01 representation change was not carried to its consumers, so Marshal now fails on well-formed Go values. One fresh-context sub-agent was spawned, given this run's id and iteration, and told to assume the work broken; it wrote its artifact before returning a verdict. It confirmed the Verify command exits 0 cache-free with `-count=1`, all six closed-task acceptance checks pass, all 17 batteries are green, cmd/ycat builds and vets clean from its own module, and that AST-02's decline is honest - it applied the change itself and watched `parser.TestNodePath` fail. It also built a differential harness across worktrees at b9b3f1b and HEAD and found zero changed encoder or rendering output over 66 strings crossed with 10 option sets and 5 shapes, plus 25 documents through AddColumn and reparse, which is independent confirmation of the byte-identity this run claimed at each step.

Its REJECT reason was reproduced here before being accepted, because a sub-agent's report is a claim like any other. `selectorNode.filter` in path.go reads the key token's Value and, when the first byte is a double quote, passes it to `strconv.Unquote` and returns that error - a compensation for the encoder's pre-NODE-01 habit of storing quoted text in the token value. `setCommentByCommentMap` runs that filter on every Marshal carrying a CommentMap, so `MarshalWithOptions` on a map whose key is `"` now returns `invalid syntax` and an empty document where it returned the full document at b9b3f1b; the same holds for `"abc`, `"a` and `"\`, and the same value without a CommentMap still encodes fine. That is a High under the envelope, which states that every value of a supported Go type is well-formed in-envelope input for Marshal and judged at full rubric severity. Filed as EVAL-01, to be fixed in path.go rather than by reverting NODE-01, because the dequoting is wrong for parsed documents on both sides of this run - the parser stores the raw value too.

The finding falsifies a claim this run made. The Settled classes line for the scalar-node class enumerates the 20 construction sites in encode.go and calls the class fixed class-complete, but a representation change has two halves and it enumerated only one: who writes the representation, never who reads it. EVAL-01's acceptance therefore includes amending that line.

Two observations were verified rather than taken on trust and filed as Lows for the ledger. `NodeUnmarshalerContext` is dispatched with the context at decode.go alongside the two interfaces the new CTX-01 comments name, so that enumeration is short by one on the decode side - my own work, caught by the gate. And `blockStyleString` panics with `strings: negative Repeat count` when AddColumn drives the column below 1, reproduced with `AddColumn(-5)`; it is pre-existing and unchanged by this run. A third observation, that `stringWithoutComment` renders a single-quoted token without doubling embedded quotes, was reported without a reproduction and is not filed: no wrong byte was produced from it, and the evidence rule forbids filing on a reading alone.

Verify command exits 0 in both parts. The ledger is no longer empty, so the closing conditions do not hold and no Converged line is written.

Learnings: A class fix that changes a representation is not complete when every producer is enumerated; the consumers of that representation are the other half of the enumeration, and they are where a compensating hack goes wrong the moment the thing it compensates for is repaired. The evaluator gate earned its cost here - the run had a green Verify command, 17 green batteries and a byte-identical encoder differential, and still shipped a High that only appeared when a second, unrelated public entry point was driven with the changed representation.

Next: EVAL-01 in iteration 10, the final iteration of budget. It is a High regression this run introduced, so it is fixed before anything else; the declaration falls to a relaunch.

## iter 10/10 | 373a1ae5-153329 | 2026-08-08 | EVAL-01 | done

Task: EVAL-01 (High) closed - the regression this run introduced is repaired. `selectorNode.filter` dequoted a mapping key whose first byte was a double quote, which stopped being a compensation and became a corruption the moment NODE-01 made the encoder store raw values. Final iteration of the budget; the run ends out of budget rather than converged, with two Lows open.

Changed: path.go (the dequoting removed from the mapping branch of selectorNode.filter), .jeffy/probes/path-key-representation (new battery, with a `paths` file), BACKLOG.md (EVAL-01 closed, the scalar-node Settled class amended with the consumer half of its enumeration).

Checkpoint: ce1b70fb90b742bb9c8f7fdb944546aa8938587d

Verification: The filed reproduction ran first and still failed on all four shapes. The fix was scoped by enumerating rather than by patching the reported line: `grep -c 'Key.GetToken().Value' path.go` returns 5 sites that match a key against a selector, and only one of them dequoted - the other four already compared the raw value, which is what both the parser and the post-NODE-01 encoder store. Removing the outlier makes all five agree, and `grep -c 'strconv.Unquote' path.go` now returns 0 while strconv itself is still used once elsewhere in the file. Acceptance check `go test ./.jeffy/probes/path-key-representation/` exits 0, having exited 1 at the start of this iteration on all four cases: Marshal returning `invalid syntax` for keys `"`, `"abc`, `"a` and `"\`, the CommentToMap to WithComment round trip dropping its comment silently, and the path read finding nothing on both an encoder-built node and a parsed document.

The parsed-document case is the one that shows this was never only a regression. `Read` on `"\"q\"": V\n` with `$.'"q"'` failed at b9b3f1b as well, because the parser has always stored the raw key on the token; the dequoting was wrong there before this run started and wrong for the encoder only after NODE-01 removed the mismatch it was compensating for. Repairing path.go therefore fixes a latent defect and the regression together, which is why the fix belongs there rather than in a revert of NODE-01.

Verify command exits 0 in both parts, `go build ./...` exits 0, `go vet ./...` exits 0, and all 18 batteries exit 0, including path-query and path-wrapper-nodes, which pin the traversal this change touches. The new battery keeps the ordinary cases green alongside the quote-leading ones - a plain `$.a.b` read and a single-quoted selector `$.'k.with.dots'` - so the evidence is about quote-leading keys rather than about paths in general.

The Settled classes line this finding falsified has been amended rather than left standing. It enumerated the 20 construction sites in encode.go and called the scalar-node class complete; it now also enumerates the consumers of that representation, with the 5 path.go key sites and the executing battery that drives them through Marshal, the comment round trip and both node sources. That is the correction the gate's REJECT bought.

Learnings: A compensating hack is invisible while the defect it compensates for is present, and it is the first thing to break when that defect is fixed - so a representation change should grep for code that reads the old shape, not only for code that writes it. When one of several sites doing the same comparison behaves differently, the odd one out is usually the bug rather than the special case: four of the five key comparisons in path.go never dequoted, and the fifth was the defect.

Next: relaunch in a fresh session. Two Lows remain, EVAL-03 then EVAL-02, and after them the run needs a fresh full audit before the evaluator gate can be re-invoked, because this run's audit is no longer the last word on a tree that has changed under it.

## iter 1/10 | f79de488-170019 | 2026-08-08 | EVAL-03 | done

Task: EVAL-03 (Low) closed as a class rather than as the instance it was filed as. The panic was reported against `ast.SequenceNode.blockStyleString`; it was in every renderer in the package.

Changed: ast/ast.go (new unexported `indentSpace` helper, the ten column and indent widths routed through it, the bespoke clamp in `SequenceEntryNode.String` folded into it), .jeffy/probes/ast-column-underflow (new battery with a `paths` file), BACKLOG.md (EVAL-03 closed, the class recorded under Settled classes), PLAN.md (the three ast rows re-swept, one Lesson).

Checkpoint: 56b7f85d15e5209c3f66b0568db4b3dee39a1bc9

Verification: The filed reproduction ran first and still panicked at the line it named, `ast/ast.go:1690`, with `strings: negative Repeat count`. Scoping the fix by enumerating rather than by patching that line changed what the finding was: `grep -rn 'strings\.Repeat' --include='*.go' .` returns 10 sites in ast/ast.go, of which one - `SequenceEntryNode.String` - already clamped its column to 1 and nine did not. The odd site out was the correct one, so the fix was to give every site the clamp the outlier already had, at one helper, and delete the outlier's own copy.

The class breadth was measured rather than asserted. A Go panic tears down the whole test binary, so the first red run reported one failing document and hid the rest; re-running the battery one document per process against the unfixed code shows 14 of 14 document shapes panicking - block and nested sequences and mappings, sequences of mappings, flow collections indented on the next line, literal and folded blocks, anchors and aliases, tags, quoted keys and values, and all three comment positions. All 14 pass after the fix. The finding as filed named one node type and the defect covered every node type the parser can build.

Acceptance: `go test ./.jeffy/probes/ast-column-underflow/` exits 0 and exited 1 before the fix, with the fixed file copied aside and restored rather than checked out. The battery is an invariant check, not a snapshot: `TestShiftIsReversible` requires a shift below the margin and back to restore the rendering byte for byte, which is the property that decides where the fix belongs - a clamp written into `AddColumn` would lose the position and fail it, so the storage stays exact and only the rendering clamps. `TestFlatDocumentsClampToTheirOwnRendering` is the known answer: a document already at column 1 has no indent to lose, so its clamped rendering must equal its natural one. `TestShiftAboveMarginIsUnchanged` is the control that passes on both sides of the fix, requiring a right shift to change the rendering and the matching left shift to restore it, so the evidence is that output moved only where a width went negative.

The sibling packages were checked and settled rather than changed, each against something runnable: `token.(*Token).AddColumn` is three lines and assigns `Position.Column` alone, so the two `IndentNum` widths in ast/ast.go and `internal/format.addIndentSpace` are not column-derived; `internal/format.formatIndent` returns early on `col <= 1`; printer/printer.go's two widths are a length difference that cannot be negative and an annotate line whose row prefix is at least 7 columns wide. The printer's remaining exposure would need a token carrying a column at or below -6, and no public path was found this iteration that puts one there - that is a reading, not a reproduction, so nothing is filed for it. Recording the re-sweep also corrected a stale sentence in the ast node rendering row, which said AST-03 remained open against SequenceEntryNode.Start; the journal shows it closed in iteration 4 of the previous run and BACKLOG.md has not listed it since, so the clause was a claim the row had outlived.

Contract preserved: the change alters rendering only for columns below 1, which previously produced no rendering at all. Verify command exits 0 in both parts, `go build ./...` exits 0, `go vet ./...` exits 0, and all 19 batteries exit 0, including the six that own ast/ast.go - broad-sweep, ast-entry-render, ast-entry-token, node-value-roundtrip, path-key-representation and scalar-roundtrip - so the sweeps that certify the three ast rows are re-run rather than assumed and those rows carry this iteration's commit.

Learnings: A panic ends the test process, so one red run measures one shape and silently hides every other; to size a panic class, run one document per process. And the odd site out is where the answer is, though not always as the bug: here nine sites were wrong and the tenth already carried the fix, so the enumeration pointed at the remedy instead of the defect.

Next: EVAL-02, the last item on the ledger, then a full fresh-evidence audit. This run inherits a ledger of two Lows and no audit of its own, so the audit is the run's own work rather than a replenishment; the evaluator gate needs it before any declaration.

## iter 2/10 | f79de488-170019 | 2026-08-08 | EVAL-02 | done

Task: EVAL-02 (Low) closed, and the count it carried was wrong in the same direction the finding was about. It said the context doc comments were short by one on the decode side; they were short by three on the decode side and two on the encode side, across six comment sites.

Changed: decode.go and encode.go and yaml.go (the six context entry point doc comments, no code), .jeffy/probes/context-cancellation (new hooks_test.go driving every hook and computing the documented set from the package AST; the sibling test's doc matching collapsed to single spaces), BACKLOG.md (EVAL-02 closed, DOC-01 filed, the class recorded under Settled classes).

Checkpoint: 0fc29e5fec7b23e1b2c0a8b3ab5535535a2ee629

Verification: The filed claim was checked before being acted on and did not survive. Computing the hook set from the package source rather than reading the comments finds 4 on the encode side - `BytesMarshalerContext`, `InterfaceMarshalerContext`, `CustomMarshalerContext`, `RegisterCustomMarshalerContext` - and 5 on the decode side, the three `*UnmarshalerContext` interfaces plus `CustomUnmarshalerContext` and `RegisterCustomUnmarshalerContext`. Every comment named exactly two. The finding saw the missing interface and missed the two registrars, which is the same failure mode it was filed against: an enumeration written by hand.

The enumeration is executed, not typed. `TestContextReachesEveryHook` installs all 9 hooks, runs each through `MarshalContext` or `UnmarshalContext` with a context carrying a value, and requires that value to come back out of the hook; it then runs each hook again with a plain background context and requires it to fail, so a passing case is evidence the context arrived rather than evidence that nothing happened. All 9 pass. `TestDocCommentsNameEveryContextHook` recomputes that set from the AST and requires each entry point's comment to name all of its side, matching on word boundaries so naming only `RegisterCustomMarshalerContext` does not satisfy `CustomMarshalerContext`.

Acceptance: `go test ./.jeffy/probes/context-cancellation/` exits 0. Against the unfixed comments, restored from HEAD with the fixed files copied aside and put back after, the same battery exits 1 and reports 15 missing names across the 6 entry points, so the check fails on the code it was written for.

One sibling assertion had to change with the wording: it looked for the literal phrase "not checked for cancellation", which a rewrapped comment splits across two lines. Its fields are now collapsed to single spaces before matching. That does not weaken it - the phrase must still be present - it only stops a doc comment's wrap column from deciding whether the test passes.

Contract preserved: this diff changes comments only, so no public function's behaviour, signature or accepted inputs moved and no Surface inventory row flips. The rows over encode.go, decode.go and yaml.go stay swept because a doc comment is not the implementing code their sweeps certify, and the certification was re-run rather than assumed: all 12 batteries owning those three paths are green, as are all 19. Verify command exits 0 in both parts, `go build ./...` exits 0, `go vet ./...` exits 0.

DOC-01 was found while enumerating and is filed rather than fixed, being a different root cause: `grep -rn '// Similar to' --include='*.go' .` returns 4 lines outside `.jeffy/`, and yaml.go's two both say "Similar to" the function they are documenting instead of its non-context variant, with `RegisterCustomMarshalerContext` also calling its callback an unmarshaler. option.go's two are correct and show the shape the other two should have.

Learnings: A finding about a hand-written enumeration is itself a hand-written enumeration, and this one was wrong the same way - check the count before fixing to it. The general form: when a task says a list is short, recompute the list from the source first, because the number in the backlog line is the previous author's reading, not a measurement.

Next: DOC-01, then the run's own full fresh-evidence audit once the ledger empties. This run has inherited findings but no audit of its own, and the evaluator gate needs one before any declaration.

## iter 3/10 | f79de488-170019 | 2026-08-08 | DOC-01 | done

Task: DOC-01 (Medium) closed as a class. It was filed over two self-referential `Similar to` clauses; enumerating the rest of the cross-reference surface found a third instance of the same root cause, so the fix is a boundary check rather than a third patch.

Changed: yaml.go (both context registrars now name their non-context variant, and RegisterCustomMarshalerContext calls its callback a marshaler), option.go (`UnmashalJSON([]byte)error` corrected to `UnmarshalJSON([]byte) error`), .jeffy/probes/doc-cross-references (new battery with a `paths` file), BACKLOG.md (DOC-01 closed, the class recorded under Settled classes).

Checkpoint: fcb7e43e04a98a1e833634cc0f7d7eab66ff4516

Verification: The filed reproduction ran first and still held: `grep -rn '// Similar to' --include='*.go' .` returns 4 lines outside `.jeffy/`, option.go's 2 correct and yaml.go's 2 naming the function their own comment documents. The third instance came from building the enumeration rather than reading it - the same defect in a different form, a backticked `UnmashalJSON` in UseJSONUnmarshaler's comment, a misspelling of `UnmarshalJSON` that appears nowhere else in the package. Three findings sharing one root cause is where instance work stops, so what was written is the check that closes the class.

The check resolves references rather than matching text it was told to expect. A `Similar to X` clause must name a symbol the package declares and must not name the symbol it documents. A `marshaler function` or `unmarshaler function` role word must agree with the direction of the function it documents, matched on word boundaries so `unmarshaler function` is not read as `marshaler function`. A symbol-looking backticked name must appear as an identifier somewhere in the package source, comments excluded.

That last rule took two attempts and the first one was wrong. Requiring a backticked name to be an exported declaration of this package failed on `YAML` in two option.go comments, which is prose emphasis rather than a reference; the fix was not to exempt those names but to ask a better question. A reference resolves against every identifier the source uses, not only the exported ones, because a doc comment legitimately names `UnmarshalJSON`, which the package declares on an unexported interface and calls but does not export; and only mixed-case exported-looking spans are treated as references, which is what separates `UnmarshalJSON` from `YAML`, `JSON` and lowercase struct tag text like `omitzero`. Under those two rules the check resolves 10 backticked names with no exemption list, and an exemption list is what it would have needed under the first rule.

Acceptance: `go test ./.jeffy/probes/doc-cross-references/` exits 0, resolving 4 `Similar to` clauses, 4 role words and 10 backticked names, and refuses to pass vacuously - each of the three tests fails if its set comes back empty. Against the unfixed comments, restored from HEAD with the fixed files copied aside and put back after, it exits 1 and all three checks fail, naming RegisterCustomMarshalerContext and RegisterCustomUnmarshalerContext as similar to themselves, RegisterCustomMarshalerContext's wrong role word, and UseJSONUnmarshaler's unresolvable `UnmashalJSON`.

Contract preserved: comments only, no code, so no public behaviour, signature or accepted input moved and no Surface inventory row flips. Verify command exits 0 in both parts, `go build ./...` exits 0, `go vet ./...` exits 0, and all 20 batteries exit 0, including every battery owning yaml.go and option.go.

Learnings: When a check needs an exemption list to pass, the rule behind it is usually wrong rather than the exceptions being special - `YAML` in backticks is not an exception to symbol resolution, it is evidence that backticks mark emphasis as well as references, and the rule had to tell them apart. An exemption list is a hand-written enumeration, which is the thing that rots.

Next: the ledger is empty and this run has no audit of its own, so iteration 4 is a full fresh-evidence audit against the Method and the Operating envelope. The evaluator gate needs it before any declaration, and with 6 iterations left after it there is budget to work whatever it files.

## iter 4/10 | f79de488-170019 | 2026-08-08 | AUDIT | audit

Task: Full fresh-evidence audit, this run's own. The previous run's audit no longer speaks for a tree that three iterations have changed under it, and the evaluator gate needs one before any declaration.

Changed: BACKLOG.md (SEC-01 filed in Now, one Proposed item), .jeffy/probes/parser-nesting-depth (new battery, committed red and without a `paths` file per the convention for a probe that reproduces an open bug).

Checkpoint: 17f4be3573525ec2c1c4a7ced5c8918817fcd3ea

Verification: Scores, against the Operating envelope and the severity rubric, over all 25 Surface inventory rows, none of which is unswept - architecture None, code quality None, security High, testing None, error handling None, performance High, documentation None, dependency hygiene None, developer experience None, correctness None, observability not applicable, UX and accessibility not applicable. The two High scores are one finding, not two: the same root cause is both a denial of service and a performance defect, and the Method says to file the root cause rather than each symptom. Closeout does not begin, because closeout requires an audit that found no High.

Security and performance, SEC-01. The envelope puts YAML document bytes in the adversarial class, so hostile hand-crafted documents are in envelope at full rubric severity. `yaml.Unmarshal` on nested flow sequences allocates 43MB for 10KB of input, 162MB for 20KB, 640MB for 40KB and 2457MB for 80KB - each doubling of the input quadrupling the memory. Extrapolating that law, a 1MB document of the same shape exhausts any ordinary process. The cause was localized rather than guessed: the lexer is linear over the same inputs at 2, 5 and 11MB, so it is not the scanner; `go tool pprof -sample_index=alloc_space` puts 95.9% of 620MB in `parser.(*context).withIndex`, whose only non-trivial work is `ctx.path = c.path + "[" + idx + "]"`. A differential settles that nesting rather than size drives it: two inputs of 40000 bytes each, one nested and one flat, allocate 640MB and 22MB. The memory is retained rather than transient, because parser/node.go calls `SetPath(ctx.path)` at every node, so the tree holds one absolute path string per node and the total is the sum of every node's depth.

The decoder's existing `maxDecodeDepth` of 10000 does not protect against this. It fires - the 20000-deep case returns "exceeded max depth" - but only after the parser has built the tree, so the error arrives with the 640MB already spent. A guard that reports the problem after paying for it is not a guard.

Alias expansion was probed and is not a defect, which is worth recording because it is where a YAML audit expects to find one. A billion-laughs document of 10 levels by 10 references, 604 bytes, decodes in no measurable time; the values are shared rather than deep-copied, so memory is linear in the document. That was confirmed with a known answer rather than a timing observation - two levels of doubling yield `[[x x] [x x]]`, so the fast decode is a real result and not a silent empty one.

Testing scores None on evidence rather than on the pass count. Every test module was run in isolation as the Method requires - token, lexer, parser and printer each `-count=1` on their own, and the root package's decoder, encoder and custom-marshaler tests each run alone - all exit 0, so no test is passing on state a sibling leaked. The conformance suite under testdata is green, and 20 of the 21 batteries are green, the twenty-first being the new red one filed above.

Dependency hygiene scores None with the strongest evidence available: go.sum is empty and go.mod declares no requirements, so the library has no third-party dependencies to have vulnerabilities. The go directive is 1.21.0 and CI covers 1.21 through 1.24 on three operating systems, plus an i386 matrix and a race build.

Developer experience is None with one disclosure: `golangci-lint` is not installed on this host, so `make lint` cannot be run here. CI runs it on every push, and this is a property of the host rather than of the project, so nothing is filed.

Observability and UX are recorded as not applicable rather than clean. A serialization library has no runtime surface to observe beyond its errors, which carry position and source context and were swept earlier; the only user-facing surface is cmd/ycat, whose CLI contract - exit status and stream discipline - is swept and pinned by its own battery.

Learnings: A guard placed after the work it guards is not a guard, and it reads like one in a grep - `maxDecodeDepth` looks like depth protection and returns the right error, while the allocation it was meant to prevent has already happened one layer down. When a limit exists, check where it fires relative to the cost, not whether it fires.

Next: SEC-01 in iteration 5, bounding nesting depth in the parser so the cost is refused rather than paid. That leaves iterations 6 through 10 for the evaluator gate and the declaration, with room for whatever the gate files.

## iter 4/10 | f79de488-170019 | 2026-08-08 | ROTATION | rotation

Task: JOURNAL.md passed 500 lines when the audit entry landed, so the oldest entries were rotated out.

Changed: JOURNAL.md (14 oldest entries removed, 10 most recent kept), JOURNAL-archive.md (created, holding those 14).

Checkpoint: 17f4be3573525ec2c1c4a7ced5c8918817fcd3ea

Verification: 24 entries before the rotation, split only on lines beginning `## iter` followed by a digit, so the indented grammar example in the preamble was neither counted nor moved - the preamble is intact in JOURNAL.md and the archive opens with its own heading. The archive holds 14 entries and the live journal holds 10, 24 together, and the live file is down to 234 lines. The archive did not exist before, so nothing was overwritten; later rotations append to it.

Learnings: none beyond the mechanics.

Next: unchanged, SEC-01 in iteration 5.

## iter 5/10 | f79de488-170019 | 2026-08-08 | SEC-01 | done

Task: SEC-01 (High) closed. The parser now bounds nesting depth, so a hostile document is refused at the point it passes the bound rather than parsed at a cost the caller never agreed to.

Changed: parser/context.go (a depth counter on the context, incremented by the two path-extending descents, and the predicate that reads it), parser/parser.go (the bound checked at the parseToken dispatch, and a package doc comment stating the limit and why it exists), .jeffy/probes/parser-nesting-depth (turned green, `paths` file added, two more test files), BACKLOG.md, PLAN.md (parser row re-swept, two Lessons).

Checkpoint: ac2244c43331dd47177065e3a167e84cac1630a7

Verification: The filed reproduction ran first and still failed on both counts. After the fix the same 40000-byte document allocates 18MB against 640MB and is refused with `[1:1002] exceeded max nesting depth`, a positioned error rather than a bare sentinel, and the equal-size nested and flat inputs now allocate 9MB and 11MB where they were 161MB and 10MB.

The fix is at one dispatch point on the claim that every structural descent reaches it, and that claim is executed rather than read off the source. `TestEveryNestingFormIsBounded` builds a document 1200 deep in each nesting form YAML offers - flow sequence, flow mapping, block mapping, block sequence, and alternating mappings of sequences - and requires each to be refused for this reason and not another; all 5 are, and all 5 fail against the unfixed parser. Its sibling requires the same 5 forms at depth 20 to parse, so the check refuses depth rather than shape.

The bound is 1000 and its value was measured rather than asserted, because the code comment claims it sits far beyond any real document. `TestCorpusStaysFarBelowTheBound` walks every YAML file the project ships, parses the 519 of 652 that are valid documents, and reports the deepest nesting as 5 - the bound is 200 times that, and the test fails if the corpus ever comes within a tenth of the bound or if any corpus file is refused by the bound itself. The remaining 133 files are the suite's deliberately invalid documents, which fail for their own reasons and are ignored unless the reason is a depth refusal.

Why the bound rather than the quadratic itself: the quadratic is in the representation - every node retains the absolute path it was parsed at - so removing it means nodes referencing a parent and a segment instead of a built string, an ast change across every `SetPath` site. That is more than one iteration and is on the ledger as a Proposed item for the owner. The bound closes the in-envelope exposure now: past it the cost is refused, and under it the worst case is single-digit megabytes.

Contract preserved: the parser rejects documents nesting deeper than 1000 where it previously parsed them, which is a public behaviour change, so the package doc comment states the bound, its reason and the measured corpus depth in the same iteration. No signature changed and no valid document in the conformance suite is affected - the Verify command exits 0 in both parts, the second part being the yaml-test-suite, and `go build ./...` and `go vet ./...` exit 0. All 21 batteries exit 0, including the 5 owning parser paths - ast-column-underflow, ast-entry-render, ast-entry-token, broad-sweep and this one - and the previously red battery is now green with its `paths` file added, so it gates from here.

Learnings: A limit's value is justified by measuring the corpus it must not refuse rather than by asserting it is generous; the deepest document in the YAML test suite nests 5, which is what makes 1000 defensible and would have made 10 indefensible. And when a fix is one check standing for many call sites, the way to earn that sentence is to provoke the failure in every form the sites represent - five documents, five refusals - not to grep for the descents and count them.

Next: the ledger is empty, this run has a full fresh-evidence audit on record, and 5 iterations remain, so iteration 6 runs the adversarial evaluator gate. A REJECT there still has budget to answer.

## iter 6/10 | f79de488-170019 | 2026-08-08 | EVALUATOR | audit

Task: Adversarial evaluator gate on an empty ledger with a clean full audit on this run's record and 4 iterations left. Verdict REJECT, two substantiated reasons, both reproduced here before being accepted. The run does not converge.

Changed: .jeffy/evaluator/f79de488-170019.md (the gate's artifact), .jeffy/probes/printer-column-underflow (new battery, committed red and without a `paths` file), BACKLOG.md (REJ-01 and REJ-02 filed, the scalar indent Settled class corrected).

Checkpoint: 632611858fd5979b4af79f4448c584839f0036e0

Verification: Evaluator: REJECT - the indent class settled at iteration 1 was not class-complete and its settlement record argued a falsehood, and this run committed a 5.8MB Windows executable that is still tracked at HEAD. One fresh-context sub-agent was spawned, given this run's id and iteration, and told to assume the work broken; it wrote its artifact before returning a verdict. It confirmed the Verify command exits 0 in both parts cache-free, all four closed tasks' acceptance checks pass, all 21 batteries are green, and `go vet ./...` is clean. It also did two things this run had not: it rendered all 652 corpus documents at the base commit and at HEAD and found the indentSpace refactor byte-identical across every one of them, and it attacked the nesting bound with tag chains, anchor prefixes, multi-document streams and 5000 siblings, finding the bound holds and resets per document.

Both reasons were reproduced here rather than taken on trust. REJ-01: `lexer.Tokenize` a two-line document, `AddColumn(-8)` on every token, then `printer.Printer.PrintErrorToken` panics `strings: negative Repeat count`; the boundary is exactly where the arithmetic says it is, -6 and -7 rendering and -8 panicking, because the annotate line is `strings.Repeat(" ", prefix+Column-1)` with a prefix of 7. REJ-02: `git ls-files` returns `scratch-audit.test.exe`, `git log --diff-filter=A` puts it in 17f4be3, this run's iteration 4 checkpoint, and it is 5835264 bytes at the repository root.

The first reason is the more serious of the two and it falsifies a sentence this run wrote. The Settled classes line for the indent class said the printer was settled because its row prefix is at least 7 columns wide. That arithmetic is true and the conclusion drawn from it is false: 7 columns of prefix absorb 6 columns of underflow. Worse than being wrong, it was load-bearing - PLAN forbids filing inside a settled class, so the sentence would have suppressed this finding in every future audit. The line now says the printer was wrongly settled and names REJ-01 as open, so the class is honestly incomplete rather than falsely closed.

The second reason is a process failure rather than a code defect, and it is mine: `go test -memprofile` leaves the compiled test binary in the working directory, the iteration 4 checkpoint runs `git add -A`, and I read the commit's file list past a name I did not recognise. The binary is 61% of `git archive HEAD` and sits inside the Go module directory, so it ships to consumers.

One observation the gate recorded is not filed: the bound is off by one between forms, flow sequences accepting depth 1001 and flow mappings 1000. A limit whose purpose is refusing documents nested 20000 deep is not made better or worse by one level, and filing it would be manufacturing work; it is named in the run report instead.

The invocation budget is now the binding constraint. The gate ran at iteration 6 of 10, which is past the midpoint, so the cap is 2 invocations rather than 3: one remains, and a second REJECT ends the run. Both fixes therefore get their own iteration and the re-invocation rides alone, which is what the closing rule asks for when the budget allows it.

Learnings: An argument written into a settled-class record is load-bearing in a way a comment is not, because the Method forbids re-filing inside a settled class - so a settlement must state what was executed, never an arithmetic argument for why a site is safe. `go test -memprofile` leaves the compiled test binary in the working directory, so a checkpoint that runs `git add -A` will commit it; profile in a scratch directory outside the repository, or check `git status` against the diff before checkpointing.

Next: REJ-01 in iteration 7, REJ-02 in iteration 8, the second and final evaluator invocation in iteration 9 with the declaration in the same iteration if it passes.

## iter 7/10 | f79de488-170019 | 2026-08-08 | REJ-01 | done

Task: REJ-01 (Medium) closed - the first evaluator reason. printer/printer.go is now inside the indent class instead of argued out of it, and the settlement record no longer contains the argument that hid it.

Changed: printer/printer.go (an `indentSpace` helper and the package's 2 widths routed through it), .jeffy/probes/printer-column-underflow (turned green, `paths` file added), .jeffy/probes/ast-column-underflow (a test driving internal/format through the decoder, `paths` file extended), BACKLOG.md (REJ-01 closed, the class settlement rewritten).

Checkpoint: f9a18da36fd95e8cdf519f842a4ce7af9298d305

Verification: The filed reproduction ran first and still panicked at -8, -50 and -5000 with the -6 and -7 cases rendering, which is the boundary the arithmetic predicts for a row prefix of 7. After the fix all 7 shifts render and each rendering carries the source line, so the check asserts a rendering rather than the absence of a panic. `grep -c 'strings\.Repeat(' printer/printer.go` returns 1, the helper's own call, and `grep -c 'indentSpace(' printer/printer.go` returns 3, the definition plus its 2 call sites, so no width in the package is built by hand. The control - an unshifted token rendering its source line and caret - passes on both sides of the fix.

The settlement record was the actual defect and it is rewritten to say what was executed. The old sentence argued that the printer was safe because its annotate line adds a prefix of at least 7 columns. That arithmetic is true; safety does not follow from it, because the expression is prefix plus column minus one and 7 columns absorb only 6 of underflow. Since the Method forbids filing inside a settled class, the sentence was not merely wrong but load-bearing - it would have deflected this finding from every future audit. Nothing in the class is settled by argument now.

internal/format was the remaining sibling and it is settled by driving it rather than by reasoning about which field feeds it. The public path that reaches format's widths is a caller parsing a document, shifting its columns, and decoding from the node, so that is what the check does: `Decoder.DecodeFromNode` on a body shifted by -5000, over a mapping, an anchor and alias pair, a nested sequence and a literal block. All four decode to their correct values. That is a narrower claim than the one it replaces and it is the one that was executed.

One thing worth recording because it nearly became a false finding: the first version of that check panicked with a nil pointer dereference and the panic was in the check, not the library - `yaml.NewDecoder(nil)` rather than a reader over empty bytes. The Lessons already say the probe is wrong more often than the library, and it was again.

Contract preserved: the printer renders where it previously panicked and is unchanged everywhere it previously rendered; no signature moved and no exported name was added. Verify command exits 0 in both parts, `go build ./...` and `go vet ./...` exit 0, and all 22 batteries exit 0, including the 3 owning printer/printer.go - broad-sweep, ycat-cli and this one - so the surfaces that render through the printer are re-driven rather than assumed.

Learnings: none new beyond the two the gate already produced, which are in the Lessons section; this iteration is their application rather than a new rule.

Next: REJ-02 in iteration 8, removing the committed test binary and closing the hole that let it in. Then the second and final evaluator invocation in iteration 9, with the declaration in the same iteration if it passes.

## iter 8/10 | f79de488-170019 | 2026-08-08 | REJ-02 | done

Task: REJ-02 (Medium) closed - the second evaluator reason. The test binary this run committed is gone, the patterns that let it in are ignored, and the index is now checked rather than trusted.

Changed: scratch-audit.test.exe (deleted, 5835264 bytes), .gitignore (build and profiling artifact patterns with the reason they are there), .jeffy/probes/no-build-artifacts (new battery), BACKLOG.md.

Checkpoint: 5f7ffa22ddc04b519a4807d768aa6e146f4dd489

Verification: The filed reproduction ran first: `git ls-files` returned the file, its blob measured 5835264 bytes, and `git archive --format=tar HEAD` measured 9646080 bytes. After the removal the same archive measurement over the staged tree is 3809280 bytes, down 5836800, which is the blob plus its tar padding, so the archive shrank by 60.5% and the module no longer carries a Windows executable to its consumers.

The sweep for siblings came back with one instance, not a class: `git ls-files` filtered for compiled and profiling suffixes returns this file and nothing else, so there was no second artifact hiding behind the first.

The acceptance is executable rather than a set of commands run once by hand. The new battery reads the real index - `git ls-files` over 1176 tracked files, none of which may carry a compiled or profiling suffix - and then checks that the four patterns a future profiling run would produce are actually ignored. Both checks fail against the state that caused the rejection: with only .gitignore and the binary restored, the first names the file and both of its matching suffixes and the second names three uncovered patterns. The tracked-file count is asserted to be over 50, so the check cannot pass by finding nothing.

Two things about that battery are worth recording because both were mistakes caught by the tooling rather than by reading. The first red run was false: `git stash --include-untracked` had stashed the new battery's own directory, so `go test` failed for having no Go files and I nearly recorded that exit 1 as the reproduction. Stashing only the two paths that mattered produced the real red. The second is that the battery went red mid-iteration on a state I thought was fixed, because `git stash pop` restored the deletion as a worktree deletion rather than a staged one, and `git check-ignore` never reports a tracked path as ignored - the file was still in the index. That is the battery working exactly as intended: it asserts on what a checkpoint would commit, not on what the working directory looks like.

Contract preserved: no Go source changed, so no public behaviour moved and no Surface inventory row went stale. Verify command exits 0 in both parts, `go build ./...` and `go vet ./...` exit 0, and all 23 batteries exit 0.

Learnings: `git check-ignore` reports a tracked path as not ignored, because a tracked file is never ignored - so a check on whether an artifact can reach a commit must read the index rather than the ignore file. And when stashing to reproduce a defect, stash the specific paths: `--include-untracked` takes the probe with it and the resulting failure is the probe's absence, not the defect.

Next: the second and final evaluator invocation in iteration 9. The ledger is empty, both rejection reasons are closed with executable acceptances, and the declaration rides in that same iteration if the verdict is PASS.

## iter 9/10 | f79de488-170019 | 2026-08-08 | EVALUATOR | converged

Task: Second and final evaluator invocation, and the declaration. Verdict PASS; the closing conditions hold and the run converges.

Changed: .jeffy/evaluator/f79de488-170019.md (the gate's second record, replacing the iteration 6 one), JOURNAL.md, BACKLOG.md (the Converged line).

Checkpoint: 3fa4016d00fbc2f24c80415f1068563efe3c9b43

Verification: Evaluator: PASS - every closed task's acceptance check holds, each was proven falsifiable by reverting the code it pins, and an independent attack on both rejection reasons found nothing. One fresh-context sub-agent was spawned, given this run's id and iteration and told this was the final invocation and that a fix which only appears to work is what it was there to catch; it wrote its artifact before returning a verdict.

It did not take the run's word for anything. It reverted each fix in turn and confirmed the matching battery goes red - the printer panicking at -8, -50 and -5000, `ast.SequenceNode.blockStyleString` panicking, all 5 nesting forms parsing at depth 1200 with 640MB from a 40000-byte document, 15 missing hook names in the context comments, and 4 clauses, 4 role words and 10 backticked names in the doc cross-references - so no battery in this run is vacuous. It planted a tracked `.test.exe` with `git add -f` to prove the artifact battery fails when it should, at 1177 tracked files.

On the two rejection reasons it went well past what this run checked. For the printer it built its own attack: 16 document shapes crossed with 19 shifts down to -2^30, driven through PrintErrorToken at both colour values, node String and MarshalYAML via ast.Walk, yaml.FormatError, Path.AnnotateSource and Decoder.DecodeFromNode, finding no panic, uncorrupted values and byte-reversible shifts, and it re-executed every grep count and shape count in the rewritten Settled classes record rather than reading them. It confirms 5 `strings.Repeat` sites remain tree-wide, two of them the guards themselves and the other three fed by IndentNum, a strings.Count and the self-guarded formatIndent. On the parser bound it binary-searched the limit to exactly 1000, checked that width costs no depth at 5000 keys and entries, that depth resets between documents, that tags and anchors cost one level each, and it added four nesting forms this run's battery does not cover - explicit keys, flow in block mapping, flow in block sequence and quoted-key nesting - all four refused past the bound.

Closing conditions, each checked this iteration: the full fresh-evidence audit at iteration 4 is on this run's record; the only commits since it are the fix for SEC-01, which that audit filed, the evaluator gate, and the fixes for REJ-01 and REJ-02, which the gate filed, plus their bookkeeping; BACKLOG.md lists no open task in Now, Next or Later; the Surface inventory lists no unswept row across 25 rows; the Verify command exits 0 in both parts cache-free, confirmed independently by the evaluator; and the evaluator returned PASS in this iteration, which is the one that declares.

Three observations the gate recorded are not rejection reasons and are deliberately not fixed here, because a fix after a PASS invalidates it and spends an invocation the declaration needs. They go to the run report and the next run's ledger. O1: the format-path check in ast-column-underflow logs and continues where it should assert a decoded value, so it can only catch a panic - the Settled record's claim it supports is true today, verified by the evaluator, but the check is weaker than the sentence. O2: .gitignore covers `*.test`, `*.test.exe`, `*.prof` and `*.pprof` but not `*.exe`, and building cmd/ycat from its own directory, which this project's own Lessons prescribe, leaves a 3441152-byte ycat.exe that git would stage - my iteration 8 reasoning that a blanket rule would buy nothing was wrong, because it considered only the battery's TempDir build and not the manual one. O3: the nesting bound is decoder-side only, so Marshal will emit a 1212202-byte document at 1100 levels that Unmarshal then refuses; 1100 levels of nested Go maps is not a plausible in-envelope shape, which is why it is an observation.

Learnings: An observation is not a small rejection, and the discipline is to leave it alone - the rule exists because runs have died fixing one after a PASS. Recording it where the next run will read it is the whole job. And O2 is the sharper lesson: I reasoned about one caller of a build command and generalised to all of them, which is the same reading-instead-of-executing failure this run has now closed four times.

Next: nothing in this run. The three observations above are the next run's first tasks, and the Proposed item on removing the parser's quadratic path representation still awaits a decision.

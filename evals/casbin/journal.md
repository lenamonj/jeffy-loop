# Journal archive

Entries rotated out of JOURNAL.md, oldest first. Appended to, never rewritten.

## iter 1/10 | c6926fab-161546 | 2026-08-31 | AUDIT | audit

Task: first audit of Apache Casbin (incubating) v3, a Go authorization library. Filled the Operating envelope, the Surface inventory and the Verify command block in PLAN.md, then probed breadth-first for findings.

Changed: PLAN.md (envelope surfaces, 26 inventory rows, Command/Oracle class/Environment fingerprint), BACKLOG.md (4 High, 1 Medium), JOURNAL.md.

Checkpoint: 9b1c7f0

Verification: baseline suite green before any change - `go test -race ./...` exited 0 in 34.5s (timed with /usr/bin/time), every package `ok` or `[no test files]`. Findings reproduced, each with a program run against the tree at HEAD 34297a1:
- CAS-1: `NewCachedEnforcer(rbac_model.conf, rbac_policy.csv)`; Enforce(alice,data2,read)=true; RemovePolicy(data2_admin,data2,read); Enforce(alice,data2,read)=true (want false). Second direction: Enforce(dave,data3,read)=false; AddPolicy(dave,data3,read); Enforce(dave,data3,read)=false (want true).
- CAS-2: temporal model `g = _, _, (_, _)` with AddNamedLinkConditionFunc(TimeMatchFunc). AddGroupingPolicy(alice,data2_admin,_,_) then Enforce=false (want true), while the batch AddGroupingPolicies path gives true. After a batch add, RemoveGroupingPolicy, RemoveGroupingPolicies and RemoveFilteredGroupingPolicy each leave Enforce=true (want false) with GetGroupingPolicy() already empty.
- CAS-3: string-adapter holding three p rules; RemovePolicy(alice,data1,read) leaves `a.Line == ""` and the next NewEnforcer over the same adapter fails with "invalid line, line cannot be empty".
- CAS-4: in-package test with MockTransactionalAdapter - BeginTransaction, tx.AddPolicy, then e.AddPolicy(bob,data2,write) outside the transaction (visible before Commit), then Commit: HasPolicy(bob,data2,write)=false. The temporary test file was removed after the run.
- CAS-5: `.gitattributes` carries export-ignore for .github and CONTRIBUTING.md only; release.yml builds the source archives with `git archive`, so once the state files are committed they enter the tarball.

Scores, claiming only the rows this audit actually read - no Surface inventory row is swept, because no known-answer battery has been executed yet, so every dimension below is silence about the 26 unswept rows rather than a clean bill: correctness High (CAS-2, CAS-3, CAS-4), security High (CAS-1), documentation Medium (CAS-5), architecture None, code quality None, error handling None, performance None, observability None on the rows read (enforcer-enforce, enforcer-cached, internal-api, transactions, util-matchers, config, model-policy, model-constraint, persist-adapters, effector-detector, frontend, ai-api). Testing not scored: the Method requires running at least one test module in isolation before scoring it clean and that has not been done. Dependency hygiene not scored: no vulnerability scanner is installed on this host. UX and accessibility do not apply - this module is a library with no user-facing surface.

Learnings: the repository is a subdirectory-free checkout of apache/casbin at 34297a1 with a clean tree; `go test -race ./...` is the whole gate and takes about 35s, so the verify gate is cheap enough to run every iteration. Reproductions that need only the public API are cheapest as a throwaway module under /tmp with a `replace` directive pointing at the project root, which keeps the working tree clean; reproductions that need in-package mocks (MockTransactionalAdapter) have to be a temporary _test.go inside the repo and must be deleted before the checkpoint.

Next: CAS-1, the top of the queue.

## iter 2/10 | c6926fab-161546 | 2026-08-31 | CAS-1 | done

Task: CAS-1 (High, runtime, security) - CachedEnforcer and SyncedCachedEnforcer served decisions taken from a policy that had since changed. Closed: the decision cache is keyed by request, the old invalidation deleted only the key spelled by the changed rule, so a role-mediated grant survived its revocation and a cached denial survived the grant that lifted it.

Changed: enforcer.go (policyChangedCallback field, notifyPolicyChanged, calls in ClearPolicy, applyModifiedModel and loadFilteredPolicy), internal_api.go (the eight policy mutators now notify on success, via named results and a deferred call), enforcer_cached.go and enforcer_cached_synced.go (register the callback in the constructor, delete the nine rule-keyed overrides and the two helpers they used, document the new contract), enforcer_cached_test.go and enforcer_cached_synced_test.go (regression tests), BACKLOG.md, JOURNAL.md.

Checkpoint: bfaa3c9

Verification: acceptance check `go test -run 'TestCacheInvalidatedByPolicyChange|TestSyncCacheInvalidatedByPolicyChange' .` passes. Run against the unfixed code - the four changed source files copied aside, restored from HEAD, the two tests run, then the fixed files copied back - it fails with five assertions: alice/data2/read true after RemovePolicy(data2_admin,data2,read), dave/data3/read false after AddPolicy(dave,data3,read), alice/data2/write true after RemoveGroupingPolicy, and the first and last of those again on the synced enforcer. Verify gate green through quiet-verify.sh (31s).
Class enumeration, since the fix claims to cover every path that changes an Enforcer's in-memory policy rather than the three the reproduction used: `grep -n 'e\.model\.\(Add\|Remove\|Update\|Clear\)Polic\|e\.model = newModel' enforcer.go internal_api.go enforcer_synced.go management_api.go rbac_api.go rbac_api_with_domains.go` returns eleven sites - eight inside the internal_api mutators, ClearPolicy, the model swap in applyModifiedModel, and the clear in LoadFilteredPolicy. Every one is inside a function that now notifies: the eight through their deferred call, the other three through ClearPolicy, applyModifiedModel and the deferred notify in loadFilteredPolicy, which the caller always enters after its clear. The deferred form there is deliberate: LoadFilteredPolicy clears the policy and then returns early when the adapter is not filtered, so a tail call would have left that path unnotified. ContextEnforcer and DistributedEnforcer carry their own parallel mutators and are not covered; neither is embedded by a cached enforcer - CachedEnforcer embeds *Enforcer and SyncedCachedEnforcer embeds *SyncedEnforcer - so no shipped decision cache can reach them.
Contract preserved: the deleted overrides had signatures identical to the embedded methods they shadowed, so callers of CachedEnforcer.LoadPolicy, RemovePolicy, RemovePolicies, ClearPolicy and the five SyncedCachedEnforcer equivalents compile and behave as before, with the cache now dropped whole instead of one key at a time; `var _ IEnforcer = &CachedEnforcer{}` in enforcer_interface.go still compiles. The existing TestCache and TestSyncCache, which pin the old exact-tuple invalidation, still pass.

Learnings: a decision cache keyed by request cannot be repaired rule by rule - one rule decides every request that reaches it through a role - so the only correct invalidation is to drop the whole cache, and the cheap-looking targeted delete is what let the defect stand. In Go, converting a function to named results to hang a defer off its outcome silently breaks any inner `:=` that redeclared the same name; `go build` catches it as "no new variables on left side of :=", so build after each such conversion rather than at the end.

Next: CAS-2, conditional role links on grouping-policy changes.

## iter 3/10 | c6926fab-161546 | 2026-08-31 | CAS-2 | done

Task: CAS-2 (High, runtime, correctness) - grouping-policy changes did not maintain conditional role links. Closed: every mutation path now maintains both kinds of link through one helper, so a temporal role granted at runtime takes effect and one revoked stops granting access.

Changed: enforcer.go (buildIncrementalRoleLinksForRules, which calls the plain and the conditional incremental builders in turn), internal_api.go, enforcer_context.go, enforcer_distributed.go (every call site routed through it; the two sites that already called both builders collapsed into one call), model_test.go (regression test), BACKLOG.md, JOURNAL.md.

Checkpoint: 971dbc3

Verification: acceptance check `go test -run TestTemporalRolesModelPolicyChanges .` passes, covering the single-rule add and remove, the batch add and remove, the filtered remove and the update path against `g = _, _, (_, _)` with util.TimeMatchFunc as the link condition. Run against the unfixed code - the four changed source files copied aside, restored from HEAD, the test run, then copied back - it fails four assertions, the first being alice/data2/read false after AddGroupingPolicy granted the role. Verify gate green through quiet-verify.sh (22s).
Class enumeration: `grep -rn 'BuildIncrementalRoleLinks\|BuildIncrementalConditionalRoleLinks' --include='*.go' . | grep -v _test | grep -v model/policy.go` returned the idiom at three files before the fix - internal_api.go, enforcer_context.go and enforcer_distributed.go - of which only two call sites in the whole tree also maintained the conditional links. After the fix that command returns only the two public method definitions in enforcer.go and the helper's own two calls; `grep -rc 'buildIncrementalRoleLinksForRules(' internal_api.go enforcer_context.go enforcer_distributed.go` returns 11, 11 and 9, and each of those files' remaining direct calls to the plain builder is zero. The helper is safe on a plain model because initRmMap gives a ptype an entry in rmMap or in condRmMap and never both, and each builder returns immediately when its map has no entry for the ptype.
Contract preserved: both public builders keep their signatures and behaviour; the helper is unexported and additive. The existing conditional-role tests - TestTemporalRolesModel, TestTemporalRolesModelWithDomain and the transitive one - still pass.
One site is deliberately not covered and is now filed rather than patched: transaction_commit.go rebuilds links with BuildRoleLinks after replacing the model, which cannot be extended to the conditional managers because rebuilding them requires clearing them first, and that discards the user's registered link condition functions.

Discovered while establishing that: CAS-6 (High, runtime, security), filed. RoleManagerImpl.Clear resets allRoles, the link condition functions live on those Role objects, and checkLinkCondition starts from passLinkConditionFunc = true and only overwrites it when a function is found - so after a plain LoadPolicy every temporal constraint is gone and the link is unconditional. Probed with a throwaway in-package test, since removed: alice/data2/read is false before LoadPolicy and true after it, on the shipped example policy whose window for that role closed in year 0. That is a fail-open security defect, not merely a lost registration.

Learnings: in this codebase a role manager's Clear is not a cheap reset - it discards the Role objects, and anything hung off a Role, link condition functions included, goes with them; a fix that reaches for a full rebuild of conditional links has to answer that first.

Next: CAS-6, the fail-open link condition functions.

## iter 4/10 | c6926fab-161546 | 2026-08-31 | CAS-6 | done

Task: CAS-6 (High, runtime, security) - a rebuild of the conditional role links discarded every registered link condition function and the constraint then failed open. Closed: the functions and their parameters now live on the role manager instead of on the Role objects, so Clear no longer takes them with it.

Changed: rbac/default-role-manager/role_manager.go (linkConditionStore holding the functions and parameters keyed by user, role and domain; ConditionalRoleManager carries one and its four accessors read and write it; ConditionalDomainManager creates one and hands the same pointer to every per-domain manager it creates; the two Role fields, their four methods and the four fan-out methods on ConditionalDomainManager deleted), model_test.go (two regression tests), BACKLOG.md, JOURNAL.md.

Checkpoint: 24e81e4

Verification: acceptance check `go test -run 'TestTemporalRolesSurviveReload|TestTemporalRolesWithDomainSurviveReload' .` passes. Against the unfixed code - role_manager.go copied aside, restored from HEAD, the tests run, then copied back - it fails five assertions, every one of them a "true, supposed to be false": alice reaching data2, data6 and data8 after a reload although those windows are closed, the same for domain2, and bob reaching data9 through a link whose window closed in year 0. All five are the fail-open direction, which is what makes this the severity it carries.
Contract preserved: the four public accessors keep their signatures, and the rbac.ConditionalRoleManager interface is still satisfied - the enforcer assigns both manager types to that interface, so the compiler checks it. The four deleted ConditionalDomainManager methods are now the promoted ConditionalRoleManager ones with identical signatures; what changes is that a registration reaches domains created later, which is the second half of this defect: the old fan-out wrote only to per-domain managers that already existed, so registering before the first rule for a domain was silently lost. The existing conditional tests - TestTemporalRolesModel, TestTemporalRolesModelWithDomain, TestTemporalRolesModelWithDomainTransitive, the conditional tests in enforcer_test.go and the role manager package's own suite - all still pass, which is what pins the read path.
Whole suite green through quiet-verify.sh (22s).
Side effect worth recording for CAS-4: the obstacle named in iteration 3 is gone. A full conditional rebuild can now clear and rebuild the links without losing the caller's registrations, so the transaction commit path is free to maintain conditional links the way it maintains plain ones.

Learnings: configuration and data must not share a lifetime - these condition functions were registered once by the caller and stored on objects the library recreates on every reload, and the fail-open default in checkLinkCondition turned that lifetime mismatch into an access grant rather than an error.

Next: CAS-3, the string adapter erasing its policy store on any single removal.

## iter 5/10 | c6926fab-161546 | 2026-08-31 | CAS-3 | done

Task: CAS-3 (High, runtime, correctness) - the string adapter's RemovePolicy erased the whole policy store. Closed: it now drops the named rule and leaves every other line as it stood, and an emptied store loads as an empty policy instead of failing.

Changed: persist/string-adapter/adapter.go (RemovePolicy filters the stored lines through lineHoldsRule, which parses each line with the same CSV settings LoadPolicyLine uses and compares fields rather than text; LoadPolicy no longer rejects an empty string), persist/string-adapter/adapter_test.go (two regression tests), BACKLOG.md, JOURNAL.md.

Checkpoint: 599d08a

Verification: acceptance check `go test -run 'Test_RemovePolicyKeepsTheOtherRules|Test_EmptyPolicyLoads' ./persist/string-adapter/` passes. Against the unfixed adapter - the file copied aside, restored from HEAD, the tests run, then copied back - both fail with "new enforcer: invalid line, line cannot be empty", which is the shape of the defect: one removal left nothing to load at all. The first test removes one of three p rules and then re-creates the enforcer over the same adapter, asserting the other two still decide their requests and the g rule is still in the stored text. Verify gate green through quiet-verify.sh (20s).
Two judgements worth recording. Every matching line is dropped rather than only the first, because LoadPolicyLine skips a duplicate instead of rejecting it, so a duplicate left behind would resurrect the rule at the next load. And a line the CSV reader cannot parse is never deleted, since this adapter holds text the caller wrote and a parse failure is not a licence to drop it.
Contract preserved: the Adapter interface is unchanged, AddPolicy and RemoveFilteredPolicy still answer "not implemented" as before - the enforcer treats that exact string as "this adapter does not persist that operation" - and the doc comment on LoadPolicy now states that an empty string is an empty policy. The existing adapter tests, including the comma round trip through SavePolicy, still pass. The empty case is not hypothetical: SavePolicy on a model with no rules writes exactly "", so before this the adapter could write a state it could not read back.

Learnings: an adapter's SavePolicy output is the input its LoadPolicy must accept; when the two disagree about a representable state - here the empty policy - the round trip is broken and only shows up once something legitimately empties the store.

Next: CAS-4, the transaction commit discarding concurrent policy changes.

## iter 6/10 | c6926fab-161546 | 2026-08-31 | CAS-4 | done

Task: CAS-4 (High, runtime, correctness) - a transaction commit rebuilt the enforcer's model from the snapshot the transaction opened on, discarding any policy written outside it in the meantime. Closed: the buffered operations are now applied to the model as it stands at commit time.

Changed: transaction_commit.go (applyOperationsToModel takes the live model as the base, and a commit that touched a grouping policy now rebuilds the conditional role links as well as the plain ones), transaction_buffer.go (addRuleIfAbsent, so an add whose rule another writer already landed does not duplicate it), transaction_test.go (two regression tests), BACKLOG.md, JOURNAL.md.

Checkpoint: 4abc9a9

Verification: acceptance check `go test -run 'TestTransactionKeepsChangesMadeOutsideIt|TestTransactionRebuildsConditionalRoleLinks' .` passes. Against the unfixed code - both transaction files copied aside, restored from HEAD, the tests run, then copied back - the first fails with "[bob data2 write] should still be in the policy after the commit" and the second with alice denied data2 after a transaction granted her the temporal role. Verify gate green through quiet-verify.sh (31s).
The duplicate guard is not decoration: Model.AddPolicy appends unconditionally and writes one PolicyMap entry per rule string, so applying a buffered add to a model that already holds that rule would leave two Policy rows sharing one map key. The test asserts the colliding rule is held exactly once after the commit.
Contract preserved: Transaction's public methods and the two-phase commit are unchanged, and the conflict detector still runs on the same condition; what changed is only which model the operations are replayed onto. The existing transaction tests all still pass, including the rollback, conflict and concurrency ones.
Not a finding, checked rather than assumed: the conditional rebuild added here made me suspect that the public BuildRoleLinks, which touches only the plain role managers, leaves a conditional model without links when autoBuildRoleLinks is off. It does not - the internal_api mutators call the incremental builder regardless of that flag, so a temporal role added with autoBuildRoleLinks disabled is already in effect before and after a manual BuildRoleLinks. Probed with a throwaway module against the project root; nothing filed.
Known limit worth stating rather than implying: this fixes the lost update, not the interleaving. A non-transactional writer does not take the commit lock, so a write racing the commit itself is still a race; the enforcer is not thread safe unless it is a SyncedEnforcer, which is the same contract the rest of the type carries.

Learnings: when a commit rebuilds shared state from a snapshot, the snapshot is only safe if every writer goes through the same lock; here the enforcer's own public API is a second writer, so the rebuild has to start from the current state and the buffered operations have to be idempotent against it.

Next: the Surface inventory - 26 rows, none swept, and they outrank the one open Medium in the queue.

## iter 7/10 | c6926fab-161546 | 2026-08-31 | SWEEP | done

Task: sweeping Surface inventory rows, which outrank the one open Medium in the queue. Three rows swept with executed known-answer batteries: util-matchers, enforcer-enforce and model-policy.

Changed: .jeffy/probes/util-matchers, .jeffy/probes/enforcer-enforce and .jeffy/probes/model-policy (each a main.go battery, run.sh, paths, claims and README), PLAN.md (the three rows flipped with the commit and the battery that swept them), JOURNAL.md.

Checkpoint: 56a1acd

Verification: the three batteries were executed through the installed run-probe.sh and print util-matchers 64/64, enforcer-enforce 43/43 and model-policy 50/50 checks passed; check-claims.sh reports 3 checked, 0 mismatched, 0 errored, 0 skipped. Verify gate green through quiet-verify.sh (20s).
Each battery was observed failing before it was trusted, on a mutation of the product rather than of the battery: util-matchers on dropping the regexp-metacharacter half of the guard in keyMatchShortcut (8 of 64 red), enforcer-enforce on removing the matches[policyIndex] == 0 guard from the allow-override branch of the effector (17 of 43 red, every one a deny that became an allow), model-policy on removing a rule by swapping the last one into its slot, which is the pre-fix shape this repository corrected in "fix: preserve policy order in Model.RemovePolicy" (1 of 50 red, the check that reads the surviving order). Each mutation was reverted and the battery re-run green immediately after.
The batteries live under .jeffy/probes/<row>/main.go and run as `go run` file arguments from the project root; Go tooling ignores directories whose name starts with a dot, so they are invisible to `go build ./...` and to the Verify command, and cannot be shipped as part of the module.
One recorded non-result worth keeping: reversing the scan direction of the priority merge in the effector changes nothing observable through Enforce, because the enforce loop calls the effector once per policy rule and stops at the first non-indeterminate answer, so at most one rule has matched when the merge runs. It is noted in the enforcer-enforce README as a mutation that does not discriminate.
Writing the enforce battery corrected one of my own hand-derivations rather than the code: under `priority(p.eft) || deny` the earlier allow that a role carries beats a later direct deny, because priority reads file order. The battery now states that explicitly, and it agrees with the suite's own TestPriorityModel.

Learnings: put a battery under .jeffy/probes/<row>/ as a single-file Go program and run it with `go run <file>`; the dot directory keeps it out of `go build ./...` and out of the module, and the file can still import the module under test. A battery is only worth its checkbox once a mutation of the product has been seen to redden it - two of the three mutations I first reached for changed nothing observable.

Next: more inventory rows - 23 remain unswept, and at three rows an iteration the map does not clear inside this budget.

## iter 8/10 | c6926fab-161546 | 2026-08-31 | SWEEP | done

Task: sweeping Surface inventory rows. The util-helpers battery was written and executed; it reddened on two real defects, so the row is not swept and both defects are filed instead.

Changed: .jeffy/probes/util-helpers (main.go, run.sh, paths, README, claims recording none while the battery is red), BACKLOG.md (CAS-7 filed High, CAS-8 filed Medium), JOURNAL.md. No Surface inventory row changed state this iteration; the ledger did, so this is not a stall.

Checkpoint: ce79851

Verification: the util-helpers battery reports 56 of 58 checks passed. The two failures are the findings, each reproduced at the enforcer level rather than only inside the battery:
- CAS-7 (High): util.Set2DEquals calls sort.Strings on every row of both arguments, mutating the caller's slices. GetPermissionsForUser hands back the model's own slices, so comparing them corrupts live policy. Reproduced with a throwaway module against the project root: basic model, AddPolicy(zoe, data1, read), Enforce true; after `util.Set2DEquals(GetPermissionsForUser("zoe"), [][]string{{"zoe","data1","read"}})` the stored rule reads [data1 read zoe] and the same Enforce returns false. The battery's own sortedArray2DEquals check fails for the same reason - the array it is handed was already permuted by the Set2DEquals check before it.
- CAS-8 (Medium): LRUCache.Put on a key already present re-links the existing node and never stores the new value, so Put("a",1); Put("a",2); Get("a") returns 1. Filed below the rubric's High with the rationale on its line: `grep -rn '\.Put(\|\.Get(' --include='*.go' rbac/` returns nothing, so the role managers' matchingFuncCache - the only internal instance - is allocated and cleared but never read or written, and no enforcement decision can depend on this. The dead field is named on the same line so the fix settles it either way.
The three green batteries from iteration 7 were re-run through run-probe.sh and still pass; check-claims.sh reports 3 checked, 0 mismatched, 0 errored, 0 skipped, the util-helpers claims file holding `none` while its battery is red. Verify gate green through quiet-verify.sh (20s).

Learnings: a battery that reddens is doing its job, and the honest move is to leave the row unswept and file what it found rather than to soften the check; a claims file records `none` until the battery is green, so the loop never quotes a passing count for an instrument that is failing. Writing checks against a comparison helper is also how the mutation showed up: the second comparison in the battery only failed because the first one had already rewritten its input, which is exactly the caller-visible defect.

Next: CAS-7, the highest open finding, then a wrapup.

## iter 9/10 | c6926fab-161546 | 2026-08-31 | CAS-7 | done

Task: CAS-7 (High, runtime, correctness) - util.Set2DEquals sorted the caller's rows in place, so comparing the permissions the enforcer returns permuted the fields of a live policy rule and revoked access. Closed as a class rather than as the one function: every Set comparison now works on copies.

Changed: util/util.go (SetEquals, SetEqualsInt and Set2DEquals sort copies; Set2DEquals renders rows through a new sortedRows helper; all three document that they leave their arguments alone), util/util_test.go and rbac_api_test.go (regression tests), .jeffy/probes/util-helpers/README.md (the battery's remaining red check), BACKLOG.md, JOURNAL.md.

Checkpoint: cf0fa4d

Verification: acceptance checks `go test -run TestSetComparisonsDoNotModifyArguments ./util/` and `go test -run TestSet2DEqualsKeepsPolicyIntact .` both pass. Against the unfixed util/util.go - copied aside, restored from HEAD, both tests run, then copied back - the util test fails on all three helpers reordering both of their arguments and the enforcer test fails with "the comparison rewrote the stored rule: [[data1 read zoe]]" followed by zoe being denied data1/read, which is the user-visible consequence this finding names. Verify gate green through quiet-verify.sh (23s).
Class enumeration: `grep -n 'sort\.' util/util.go` returned seven sites before the fix - one in SortArray2D, which sorts by name and by contract and is left alone, and two each in SetEquals, SetEqualsInt and Set2DEquals, every one of them sorting a slice the caller owns. After the fix the same command returns six sites, all of them operating on a local copy or, in SortArray2D's case, on the argument it is named for. The three fixed functions are the whole class; nothing else in the package sorts.
Battery ownership: the diff touches util/util.go, which .jeffy/probes/util-helpers/paths declares, so that battery was run through run-probe.sh in this iteration. It is still red, and deliberately: it reported 56 of 58 before this change and 57 of 58 after, the recovered check being sortedArray2DEquals/other-order, which had been failing only because the Set2DEquals call before it had already permuted its input. The one remaining failure is lru/overwrite-value, which is CAS-8, filed and open. No row was flipped, so nothing certifies code this change outdated.
Contract preserved: all three functions keep their signatures and their answers - the tests that use them across rbac_api_test.go, model_test.go and the role manager suite still pass, and the battery's own equality checks still discriminate, with a negative case per function added to the new test so the copies cannot be trivially satisfied.

Learnings: a query that sorts its arguments is a mutation wearing a question mark; when the arguments routinely alias a library's own state, the cost lands on the caller's data rather than on the answer.

Next: the final iteration, a wrapup - CAS-8 and CAS-5 stay open with 23 rows unswept, and the next run picks them up.

## iter 10/10 | c6926fab-161546 | 2026-08-31 | WRAPUP | done

Task: final iteration of the budget. The ledger holds two Medium items and no High, 23 of 26 Surface inventory rows are unswept, and the projection puts the map clearing around iteration 25 of a 10-iteration budget, so the run ends out of budget rather than converged. This entry tidies the ledger and writes the handoff.

Changed: JOURNAL.md. BACKLOG.md needed no tidying - Now is empty, Next carries CAS-8 and CAS-5, Later, Proposed, Settled classes and Declined are empty, and every closed task was deleted from it by the iteration that closed it.

Checkpoint: 8725252

Verification: verify gate green through quiet-verify.sh (20s). All four batteries run through run-probe.sh: util-matchers 64/64, enforcer-enforce 43/43, model-policy 50/50, util-helpers 57/58 with its one failure being the open CAS-8, which is why its claims file reads none and its row stays unswept. check-claims.sh reports 3 checked, 0 mismatched, 0 errored, 0 skipped. No Surface inventory row changed state this iteration and no ledger item did either; this is a WRAPUP, which the stall rule exempts, and the previous entry closed CAS-7 rather than recording the same.

Handoff for the next run, in the order the queue will take them:
- CAS-8 (Medium) is the first item: LRUCache.Put ignores the new value for an existing key. The fix is a few lines in util/util.go, and the util-helpers battery already holds the failing check, so the row it blocks - util-helpers - can be swept in the same iteration once the battery goes green and its claims file gets its summary line.
- CAS-5 (Medium) is the second: add PLAN.md, BACKLOG.md, JOURNAL.md, JOURNAL-archive.md and .jeffy/ to .gitattributes as export-ignore, next to the .github and CONTRIBUTING.md entries already there.
- Then the map: 23 rows unswept. The three batteries written this run are the pattern to copy - a single-file Go program under .jeffy/probes/<row>/, run with `go run` from the project root, with a paths file, a claims line carrying its summary, and a README recording the product mutation the battery was observed reddening on. The rows with the most decision-bearing surface behind them are management-api, rbac-api, rbac-api-domains, enforcer-synced, enforcer-cached, transactions and rbac-role-manager.
- A relaunch should be a fresh session: context reached 2.4x its opening size by the end of this run, and the state files carry everything forward.

Learnings: a run that maps 26 rows and sweeps 3 of them is not a failed run, but the map's size is worth knowing at iteration 1 rather than at iteration 7 - the arithmetic was available the moment the inventory was written, and stating it there would have set the expectation for the whole run.

Next: nothing in this run; the budget is spent.

## iter 1/10 | a903438e-170435 | 2026-08-31 | SWEEP | done

Task: sweeping Surface inventory rows. No open High stood above the map, so the queue top was the 23 unswept rows. Two batteries were written and executed - management-api and config - and both reddened on real defects, so neither row flips and four findings are filed instead.

Changed: .jeffy/probes/management-api (main.go, run.sh, paths, README.md, claims recording none while the battery is red), .jeffy/probes/config (same five files), BACKLOG.md (CAS-9 and CAS-10 filed High in Now, CAS-11 and CAS-12 filed Medium in Next), JOURNAL.md. No product file changed and no Surface inventory row changed state; the ledger did, so this is not a stall.

Checkpoint: 806d917

Verification: management-api reports 88 of 106 checks passed, config reports 52 of 54, both run through run-probe.sh. Every failure in both is one of the four findings and nothing else. Verify gate green through quiet-verify.sh (23s). check-claims.sh reports 3 checked, 0 mismatched, 0 errored, 0 skipped - the two new claims files read none while their batteries are red.

Findings, each reproduced outside its battery in a throwaway module against the project root:
- CAS-9 (High): UpdateFilteredPolicies takes the rules it is meant to remove only from the adapter, and no adapter this module ships supplies them - file-adapter answers "not implemented", string-adapter is not an UpdatableAdapter, a nil adapter skips the call. With the file adapter and autoSave on, over p=[alice secret read],[alice public read], UpdateFilteredPolicies([[alice reports read]], 0, "alice") reported false with a nil error, left the policy holding all three rules, and Enforce("alice","secret","read") stayed true across the call. A revocation performed through this API silently does not happen.
- CAS-10 (High): the batch and update paths assert an optional adapter capability and call through it in one expression, so an adapter implementing only persist.Adapter panics. Enumerated by provoking every public entry point against a string-adapter-backed enforcer rather than by reading the source: AddPolicies, AddPoliciesEx, RemovePolicies, UpdatePolicy, UpdatePolicies, UpdateFilteredPolicies, AddGroupingPolicies, RemoveGroupingPolicies, UpdateGroupingPolicy, SelfAddPolicies, SelfAddPoliciesEx, SelfRemovePolicies, SelfUpdatePolicy and SelfUpdatePolicies panic; AddPolicy, RemovePolicy and RemoveFilteredPolicy return normally. The surrounding code already tolerates an adapter answering "not implemented", so the unimplemented interface is the only unhandled case.
- CAS-11 (Medium): model.AddPolicy stores the caller's slice, and only Enforcer.AddNamedPolicy copies before calling it, so every other add path retains caller memory. Three AddGroupingPolicy calls through one reused two-element buffer left a single grouping rule reading the last subject; after SavePolicy and LoadPolicy the other two subjects lost the role. Filed Medium rather than High with the rationale on its line: the wrong decision needs the caller to mutate a slice it passed in.
- CAS-12 (Medium): config.Config stores an option and a section under the name written in the file while get and Set lowercase the key, so a name carrying an uppercase letter is accepted and then never returned. The model loader is unaffected - a capitalised model file fails with "missing required sections" - so the consequence is confined to a caller using the exported config package directly.

Learnings: name a battery check after the single behaviour it isolates, and keep every other input to it in the shape the check is not about - two comment-stripping checks here failed on the case-handling defect instead, which read as a comment bug until the keys were lowercased. The management-api row also wants splitting: 65 exported methods behind one checkbox is far more surface than the frontend row's two, and the rows-swept count overweights the small ones while it stands.

Next: CAS-9 and CAS-10, the two open High findings, one per iteration. PLAN.md carries no `Verify summary pattern` or `Verify count` line, so the wrapper's green line quotes no figure; a later iteration should fill both before any declaration.

## iter 2/10 | a903438e-170435 | 2026-08-31 | CAS-9 | done

Task: CAS-9 (High, runtime, correctness) - UpdateFilteredPolicies and UpdateFilteredNamedPolicies never removed the rules they were meant to replace, so a revocation performed through this API silently did not happen and the new rules were added beside the old ones.

Changed: internal_api.go (updateFilteredPoliciesWithoutNotify reads the rules to replace from the model when the adapter did not supply them, and no longer suppresses the changed report when the replacement set is empty), management_api_test.go (regression test), PLAN.md (one Lessons line), BACKLOG.md (CAS-9 deleted, CAS-13 filed Medium), JOURNAL.md.

Checkpoint: b0be335

Verification: acceptance check `go test -run TestUpdateFilteredPoliciesReplacesMatchingRules .` passes. Against the unfixed internal_api.go the same test fails on all four of its assertions - the call reports no change, the policy reads [[alice secret read] [alice public read] [bob data2 write] [alice reports read]] where it should read [[alice reports read] [bob data2 write]], Enforce("alice","secret","read") is still true after the revocation, and the follow-up removal of bob's only rule also reports no change while removing nothing. Verify gate green through quiet-verify.sh (23s).
Root cause: oldRules was sourced only from `e.adapter.(persist.UpdatableAdapter).UpdateFilteredPolicies`, and no adapter in this repository supplies it - file-adapter answers "not implemented", string-adapter is not an UpdatableAdapter, AdapterMock lacks UpdateFilteredPolicies, and a nil adapter or autoSave off skips the block. oldRules therefore stayed empty, model.RemovePolicies removed nothing, and model.AddPolicies still ran. The fix reads the filtered rules from the model in that case, which is the same store the enforcement path reads.
Contract preserved: the two public entry points keep their signatures, and the returned bool keeps its meaning - rules were replaced - which is now true when rules actually were. No test pinned this function before this iteration: `grep -rn 'UpdateFilteredPolicies\|UpdateFilteredNamedPolicies' --include='*_test.go' .` returned nothing, so the suite constrained nothing here and the whole module stays green. The second change, dropping `ruleChanged = ruleChanged && len(newRules) != 0`, is an observable behaviour change recorded here for the reason the Constraints require: with the first fix in place, leaving it meant a replacement with an empty set removed rules and still reported false, which is a destructive edit reported as a no-op.
Battery ownership: the diff touches internal_api.go, declared by .jeffy/probes/management-api/paths, so that battery ran through run-probe.sh in this iteration. It moved from 88 of 106 to 90 of 106, the two recovered checks being updateFiltered/reported and updateFiltered/old-gone. It is still red and its row stays unswept: the remaining sixteen failures are the fourteen baseAdapter panics of CAS-10 and the two aliasing checks of CAS-11, both open. Its claims file still reads none.

Learnings: when a function takes the data it is about to mutate from an optional collaborator, the case worth driving first is the one where that collaborator declines - here every adapter in the repository declines, so the declining path was not an edge case but the only path any in-repo configuration takes, and the feature had never worked with any adapter this module ships.

Next: CAS-10, the remaining open High - the unchecked adapter capability assertions that panic against a base adapter.

## iter 3/10 | a903438e-170435 | 2026-08-31 | CAS-10 | done

Task: CAS-10 (High, runtime, error handling) - the batch and update paths asserted an optional adapter capability and called through it in one expression, so any adapter implementing only persist.Adapter crashed the process with a raw interface-conversion panic. Closed as a class across all three files that carry the idiom, not as the one entry point that surfaced it.

Changed: internal_api.go, enforcer_distributed.go, enforcer_context.go (every assertion on an optional adapter capability is now checked), management_api_test.go (three table-driven regression tests covering all three files), BACKLOG.md (CAS-10 deleted, the class recorded under Settled classes with its enumerating command), JOURNAL.md.

Checkpoint: 776b620

Verification: acceptance checks both pass. `go test -run TestBaseAdapterSurvives .` is green over its subtests, and the enumerating command `grep -rnE '\.\(persist\.[A-Za-z]+\)\.' --include='*.go' . | grep -v _test | grep -v '/probes/'` now prints nothing, where before the fix it listed sites in internal_api.go, enforcer_distributed.go and enforcer_context.go. Verify gate green through quiet-verify.sh (29s).
Class enumeration, built by provoking rather than by reading: the three fixed files were restored from HEAD and every subtest was run in its own process, because a panic aborts the test binary and one run exhibits only the first site. All twenty-four subtests panicked on an interface conversion against the unfixed code and all twenty-four pass against the fixed code. Those subtests cover every site the enumerating command listed: the five in internal_api.go reached through fourteen public entry points, the five in enforcer_context.go through the Ctx entry points, and the five in enforcer_distributed.go through the dispatcher-facing Self methods.
Contract preserved: no signature changed, and an adapter that does implement the capability takes exactly the branch it took before - the checked assertion succeeds and the same call is made. For an adapter that does not, the panic becomes an in-memory edit with persistence skipped, which is not a new behaviour but the one the surrounding code already produced for an adapter answering "not implemented"; file-adapter reaches that path today for every incremental edit and persists through SavePolicy instead. `grep -rn 'BatchAdapter\|UpdatableAdapter' --include='*_test.go' .` returned only the comment lines in the tests added this iteration, so no existing test pinned these paths, and the whole module stays green.
Battery ownership: the diff touches internal_api.go, declared by .jeffy/probes/management-api/paths, so that battery ran through run-probe.sh in this iteration. It moved from 90 of 106 to 104 of 106, the recovered checks being every baseAdapter one. It is still red and its row stays unswept: the two remaining failures are the aliasing checks of CAS-11, which is open. Its claims file still reads none.

Learnings: a panic aborts the Go test binary, so a table of cases that provoke panics reports only its first case - run each case in its own process when the enumeration itself is the evidence, or the differential silently covers one site and claims a class.

Next: no open High remains, so the queue top returns to the map - twenty-three unswept Surface inventory rows, and CAS-11 blocks the management-api row from flipping.

## iter 4/10 | a903438e-170435 | 2026-08-31 | SWEEP | done

Task: sweeping Surface inventory rows, the queue top with no open High. Three batteries were written and executed - log-errors-constant, persist-cache and model-constraint - and one more check group was added to management-api. One row flips; the other two reddened on real defects and stay unswept, and four findings are filed.

Changed: .jeffy/probes/log-errors-constant (new, green), .jeffy/probes/persist-cache (new, red), .jeffy/probes/model-constraint (new, red), .jeffy/probes/management-api (constraint check group added, README extended), PLAN.md (log-errors-constant row swept), BACKLOG.md (CAS-14 and CAS-15 filed High, CAS-16 and CAS-17 filed Medium), JOURNAL.md. No product file changed; the Surface inventory and the ledger both did, so this is not a stall.

Checkpoint: 63505a8

Verification: log-errors-constant reports 53 of 53 and its row is flipped, its claims file carrying that summary line. persist-cache reports 52 of 54, model-constraint 29 of 31, management-api 105 of 110 - every failure across the three red batteries is one of the four findings and nothing else. All four ran through run-probe.sh. check-claims.sh reports 4 checked, 0 mismatched, 0 errored, 0 skipped. Verify gate green through quiet-verify.sh (19s).
The log-errors-constant battery passed on first execution, so it was observed failing on a deliberate mutation before being allowed to certify anything: replacing the event-type filter in OnBeforeEvent with an unconditional entry.IsActive = true, the inert-parameter defect this project's own Surface inventory warns about. It reddened to 51 of 53 on log/filter-disabled-type and log/inactive-writes-nothing, and the mutation was reverted in the same iteration - `git diff --name-only log/` is empty.
Findings, each reproduced at the enforcer level in a throwaway module against the project root:
- CAS-14 (High): a grouping rule that violates a constraint is reported as rejected and left in force. AddRoleForUser("alice","finance_approver") returns ok=false with "constraint violation [c]", and afterwards the grouping policy holds the rule, GetRolesForUser returns both roles, and Enforce("alice","invoice","approve") is true. The retained rule also wedges later edits: AddRoleForUser("carol","auditor") then fails with alice's violation. The existing TestConstraintRollback asserts only that an error comes back, never that the rule was undone, which is why the suite is green over this.
- CAS-15 (High): sod, sodMax and rolePre read only directly assigned roles. Assigning dave finance_requester, dave team_lead and team_lead finance_approver is accepted with no violation, while GetImplicitRolesForUser("dave") returns all three and dave can both request and approve the same invoice.
- CAS-16 (Medium): cache.Cache documents its survival time as a time.Time and both implementations assert time.Duration, so a caller following the documentation panics.
- CAS-17 (Medium): a constraint section whose value is empty is dropped at load and validates clean, so nothing distinguishes "no constraints" from "the constraint you wrote was discarded".

Learnings: a battery that passes on first execution has proved nothing yet, and the cheapest way to earn the row is to break the code deliberately and watch the right checks go red - the inert-filter mutation here reddened exactly the two checks that exist to catch it, which is what makes the other fifty-one worth reading. Also worth recording: an enforcer-level defect surfaced by a model-level sweep belongs in the battery whose paths file already declares the file that carries it, not in the battery that noticed it.

Next: CAS-14, the constraint rollback, is the top of the queue - a security control that reports a block it did not apply.

## iter 5/10 | a903438e-170435 | 2026-08-31 | CAS-14 | done

Task: CAS-14 (High, runtime, security) - a grouping rule that violated a constraint was reported as rejected and left in force, so a separation-of-duties control reported a block it had already applied. Closed by moving validation ahead of the change at every site rather than by unwinding it afterwards.

Changed: model/constraint.go (ValidateConstraintsWithPolicy added, taking the grouping policy to validate; ValidateConstraints now delegates to it), internal_api.go (validateGroupingChange added, and all eight post-mutation validation calls replaced by a pre-mutation one; the now-unreferenced validateConstraintsForGroupingPolicy helper deleted), constraint_test.go (TestConstraintRollback given the assertions its name promised, plus two new tests), BACKLOG.md (CAS-14 deleted), JOURNAL.md.

Checkpoint: 4510e52

Verification: `go test -run TestConstraint .` passes. Against the unfixed internal_api.go and model/constraint.go, restored from HEAD, it fails on TestConstraintRollback, on all six subtests of TestConstraintRefusalAppliesNothing and on TestConstraintRefusedRemovalKeepsThePolicy, reporting in each case that the refused rule was stored, that the refused grant is in force, and that a later unrelated edit failed behind it. Verify gate green through quiet-verify.sh (23s).
Why pre-validation rather than rollback: at every one of the eight sites the adapter write happened before the model change, so undoing the model would still have left the rejected rule in the store. Validating the policy the change would produce, before anything is written, is the only shape that keeps the adapter, the model and the role links consistent. The candidate policy is the current g policy minus the rules the change removes plus the rules it adds; the constraint engine reads the "g" ptype, so a change to any other grouping type validates the stored policy exactly as before. For the two filtered paths the removal set is resolved with model.GetFilteredPolicy before the adapter is asked, which is what lets those two validate as early as the rest.
Contract preserved: no signature changed, and a change the constraints accept follows the same path it followed before. A change they reject now returns the same error with nothing applied, which is the fix. The eight entry points were enumerated from the call sites of the deleted helper and each was given the removed and added sets its own mutation performs; `grep -rn 'validateConstraintsForGroupingPolicy' --include='*.go' .` now returns nothing outside .jeffy/.
Battery ownership: the diff touches internal_api.go and model/constraint.go, declared by .jeffy/probes/management-api/paths and .jeffy/probes/model-constraint/paths, and both ran through run-probe.sh. management-api moved from 105 of 110 to 108 of 110, the three recovered checks being the constraint group; its two remaining failures are CAS-11. model-constraint is unchanged at 29 of 31, its failures being CAS-15 and CAS-17. model-policy was re-run and is 50 of 50. No swept row's battery declares a path this diff touched, so no row needed re-recording.

Learnings: when a check runs after the mutation it is meant to gate, moving it earlier is usually the smaller change as well as the correct one - the rollback alternative here would have had to unwind an adapter write too, at eight sites, and would still have been a repair rather than a refusal.

Next: CAS-15, the remaining open High - the same constraint engine reading only directly assigned roles, so one intermediate role bypasses it.

## iter 6/10 | a903438e-170435 | 2026-08-31 | CAS-15 | done

Task: CAS-15 (High, runtime, security) - the sod, sodMax, rolePre and roleMax constraints read only directly granted roles, so a single intermediate role bypassed every one of them. Closed by resolving the roles a subject actually holds before any constraint is evaluated.

Changed: model/constraint.go (buildPrincipalRoleMap added, resolving inherited grants per principal; buildUserRoleMap now collapses that resolution to the shape the per-user constraints compare; validateRoleMax counts holders from the same resolution instead of counting raw grouping rows), constraint_test.go (six subtests), BACKLOG.md (CAS-15 deleted), JOURNAL.md.

Checkpoint: 7112336

Verification: `go test -run TestConstraintsFollowRoleInheritance .` passes. Against the unfixed model/constraint.go, restored from HEAD, four of its six subtests fail: sod and sodMax do not fire when the second role is reached through an intermediate role, roleMax does not count a holder that arrives through one, and rolePre wrongly refuses a user whose prerequisite is held through one. The remaining two subtests pass against both trees by design - they are the guards on what the widened check must not now do, a cycle in the grouping policy and a link that exists only in another domain - so they are stated here as regression guards rather than as evidence of the defect. Verify gate green through quiet-verify.sh.
Contract preserved and behaviour changes recorded, per the Constraints: no signature changed and the resolution is computed from the grouping policy handed in, so it works on the candidate policy the previous iteration's pre-validation builds rather than on the applied state. Three observable changes. Constraints now fire on inherited grants, which is the fix. rolePre becomes more permissive in one case - a prerequisite held through an intermediate role now counts as held - which is the same correction seen from the other side. And roleMax counts distinct principals holding the role rather than grouping rows naming it; that can never count fewer than before, because each counted row is a distinct principal-and-domain pair and the model rejects duplicate rules, so no violation the old count caught is lost.
Inheritance is followed only within the domain a grant was made in, so a role granted in one domain never reaches a role granted in another; grants are still merged per subject afterwards, which is the comparison shape the per-user constraints already had, so the cross-domain direct case behaves exactly as it did. Cycles terminate on a visited set.
Battery ownership: the diff touches model/constraint.go, declared by .jeffy/probes/model-constraint/paths, which ran through run-probe.sh and moved from 29 of 31 to 30 of 31; its one remaining failure is CAS-17, still open, so its row stays unswept and its claims file still reads none. management-api was re-run at 108 of 110, its two failures being CAS-11. No swept row's battery declares a path this diff touched.

Learnings: when a fix widens a check, the tests that matter most are the ones for what it must not now catch - the cycle guard and the domain guard here pass against both trees and prove nothing about the defect, but they are the only reason the widening can be trusted not to have invented violations of its own.

Next: no open High remains, so the queue top returns to the map - twenty-two unswept rows with four iterations left, which will not clear, so the next sweep should take the rows carrying the most decision-bearing surface.

## iter 7/10 | a903438e-170435 | 2026-08-31 | SWEEP | done

Task: sweeping Surface inventory rows, the queue top with no open High. One battery was written and executed - rbac-api, the largest decision-bearing surface left on the map. It reddened on a real defect, so the row does not flip and the finding is filed. This iteration also repaired a flaky test this run itself introduced, which the verify gate caught.

Changed: .jeffy/probes/rbac-api (new, red), constraint_test.go (one order-dependent assertion replaced by a set comparison), BACKLOG.md (CAS-18 filed High), JOURNAL.md. No product file changed; the ledger did, so this is not a stall.

Checkpoint: 8bc6e88

Verification: rbac-api reports 93 of 95, run through run-probe.sh; both failures are CAS-18 and nothing else. check-claims.sh reports 4 checked, 0 mismatched, 0 errored, 0 skipped. Verify gate green through quiet-verify.sh, run twice after the repair below.
Verify gate failure and its repair: the gate came back red on TestConstraintRefusedRemovalKeepsThePolicy, a test this run added in iteration 6. Nothing in this iteration touched product code - the diff was probe files and the ledger - so the iteration had not broken anything; the test itself was order-dependent. It compared GetRolesForUser output with util.ArrayEquals, which is order-sensitive, against a role manager whose ordering is unspecified, and it flaked: eight consecutive runs of that test alone gave five failures and three passes. It passed at iteration 6's checkpoint by luck, and the gate there certified a green suite that was green by coin toss. The assertion now compares with util.SetEquals, and twenty consecutive runs of that test pass. Scored as a test-class defect, which the severity ceiling puts at Low always, and repaired in the iteration that found it rather than filed, since the fix was one line.
Finding, reproduced outside the battery in a throwaway module against the project root:
- CAS-18 (High): GetImplicitUsersForResource, GetNamedImplicitUsersForResource and GetImplicitUsersForResourceByDomain expand one level of inheritance. Over p=[senior data3 read] with g=[alice data2_admin] and [data2_admin senior], GetImplicitUsersForResource("data3") returns [[data2_admin data3 read]] - the intermediate role, which the function's own doc says is excluded - while Enforce("alice","data3","read") is true, so the user who actually reaches the resource is the one name missing. The same shape in a domain gives the same answer from GetImplicitUsersForResourceByDomain. Both sites were enumerated by provoking them, not by reading the source, and the documented example in the doc comment is one level deep, which is exactly why the defect is invisible from it.

Learnings: a test that compares an unordered result with an order-sensitive helper is a coin toss that reports as a pass, and one green verify gate is not evidence that it is stable - when an assertion reads a map-backed or role-manager-backed result, compare it as a set, and re-run a newly added test several times before trusting the gate that passed it.

Next: CAS-18, the open High. The map stands at four rows swept of twenty-six with three iterations left, so it will not clear this run.

## iter 8/10 | a903438e-170435 | 2026-08-31 | CAS-18 | done

Task: CAS-18 (High, runtime, correctness) - the three resource-to-users functions expanded one level of role inheritance, returning the intermediate role their own documentation says is excluded and omitting the user who actually reaches the resource. Closed at both sites that carry the idiom.

Changed: rbac_api.go (GetNamedImplicitUsersForResource and GetImplicitUsersForResourceByDomain now expand with rm.GetImplicitUsers and drop names that are themselves roles), rbac_api_test.go (three subtests), .jeffy/probes/rbac-api (claims now carries the green summary line, README updated), PLAN.md (rbac-api row swept), BACKLOG.md (CAS-18 deleted), JOURNAL.md.

Checkpoint: abd9cb6

Verification: `go test -run TestImplicitUsersForResourceWalksTheWholeHierarchy .` passes, and ten consecutive runs pass, which is the check the previous iteration's flaky assertion earned. Against the unfixed rbac_api.go, restored from HEAD, its first two subtests fail with GetImplicitUsersForResource, GetNamedImplicitUsersForResource and GetImplicitUsersForResourceByDomain each returning the intermediate role. The third subtest, the one-level example from the functions' own doc comments, passes against both trees and is stated here as a backward-compatibility guard rather than as evidence of the defect. Verify gate green through quiet-verify.sh.
Root cause and why it hid: both sites called rm.GetUsers, which is one level, inside functions named and documented as implicit, and applied the isRole filter to the policy subject before the expansion instead of to what the expansion produced. Either half alone would have been enough to return a role: the fix changes both. The doc comment on each function shows a one-level example, where GetUsers and GetImplicitUsers agree, so the defect is invisible from the documentation and from any test written against it.
Contract preserved: no signature changed, and the one-level shape both functions document returns exactly what it returned before - the third subtest pins that. What changes is deeper hierarchies, where the answer becomes the users rather than an intermediate role, which is what the doc already promised.
Battery ownership: the diff touches rbac_api.go, and `grep -l 'rbac_api.go' .jeffy/probes/*/paths` names only .jeffy/probes/rbac-api, which ran through run-probe.sh and is now 95 of 95. Its claims file carries that summary line and check-claims.sh reports 5 checked, 0 mismatched, 0 errored, 0 skipped. The rbac-api row is flipped at this iteration's checkpoint.

Learnings: when a function's name says implicit and its helper says direct, the doc comment is the last place the mismatch will show, because doc examples are written at the depth where the two agree - the shape worth driving is one level deeper than whatever the documentation illustrates.

Next: no open High remains. Two iterations are left and the map stands at five rows swept of twenty-six, so the run will end out of budget; the next iteration sweeps what it can and the last one writes the handoff.

## iter 9/10 | a903438e-170435 | 2026-08-31 | SWEEP | done

Task: sweeping Surface inventory rows, the queue top with no open High. Three batteries were written and executed - effector-detector, persist-core and frontend. Two flip their rows; the third reddened on a real defect and stays unswept, with the finding filed.

Changed: .jeffy/probes/effector-detector (new, green), .jeffy/probes/persist-core (new, green), .jeffy/probes/frontend (new, red), PLAN.md (two rows swept), BACKLOG.md (CAS-19 filed High), JOURNAL.md. No product file changed; the Surface inventory and the ledger both did, so this is not a stall.

Checkpoint: 091a1b3

Verification: effector-detector reports 36 of 36, persist-core 35 of 35, frontend 31 of 32, all run through run-probe.sh. The one frontend failure is CAS-19 and nothing else. check-claims.sh reports 7 checked, 0 mismatched, 0 errored, 0 skipped. Verify gate green through quiet-verify.sh.
Both green batteries passed on first execution, so neither was allowed to certify its row until it had been seen to fail. Deleting the matched-deny branch from the effector's deny-override case, which makes that expression allow everything, reddens effector-detector to 34 of 36 on denyOverride/matched-deny and denyOverride/deny-in-the-middle. Making PolicyLineToCsv join the raw fields instead of the CSV-quoted ones reddens persist-core to 32 of 35 on the three round-trip checks that carry a comma or a quote. Both mutations were reverted in the same iteration and `git diff --name-only` shows no product file changed.
Four of the frontend battery's first five failures were my own wrong expectations rather than defects, and correcting them is worth recording: the old frontend shape is a map of action to objects rather than a per-ptype rule map, and the HTML-escaping check has to look for the & escape rather than for an ampersand, since the matcher legitimately contains two of them. Only the fifth survived contact with the code.
Finding, reproduced outside the battery in a throwaway module against the project root:
- CAS-19 (High): Model.ToText prints the section letter where the ptype belongs. Over a policy_definition holding `p = sub, obj, act` and `p2 = sub, act`, ToText returns both lines named `p`, so the text does not describe the model and reloading it loses a definition. The g and c sections beside it format the ptype correctly, which is what makes this a slip rather than a design. CasbinJsGetPermissionForUser ships that text to the browser.

Learnings: when a battery's first run is red, check which failures are the instrument before filing any of them - four of five here were my own expectations about an API I had not read closely enough, and filing them would have put four fabricated findings on the ledger. The one that survived was the one I confirmed against the implementation.

Next: CAS-19 is the open High, but this is the last iteration of the budget, so the next entry is a wrapup and the finding carries to the next run.

## iter 10/10 | a903438e-170435 | 2026-08-31 | WRAPUP | done

Task: final iteration of the budget. The ledger holds one High and seven Mediums and nineteen of twenty-six Surface inventory rows are unswept, so the closing-audit exception does not apply and this entry tidies the ledger and writes the handoff. The run ends out of budget, not converged.

Changed: JOURNAL.md. BACKLOG.md needed no tidying - Now holds CAS-19, Next holds the seven Mediums ordered by class with the one build-ci item last, Later, Proposed and Declined are empty, and every task closed this run was deleted by the iteration that closed it.

Checkpoint: 2e7342d

Verification: verify gate green through quiet-verify.sh (19s). All thirteen batteries run through run-probe.sh: effector-detector 36/36, enforcer-enforce 43/43, log-errors-constant 53/53, model-policy 50/50, persist-core 35/35, rbac-api 95/95 and util-matchers 64/64 are green; config 52/54, frontend 31/32, management-api 108/110, model-constraint 30/31, persist-cache 52/54 and util-helpers 57/58 are red, and every failure across those six is an open ledger item. check-claims.sh reports 7 checked, 0 mismatched, 0 errored, 0 skipped. No Surface inventory row changed state this iteration and no ledger item did; this is a WRAPUP, which the stall rule exempts, and the previous entry was a sweep that flipped two rows.

Handoff for the next run, in the order the queue will take them:
- CAS-19 (High) is first: Model.ToText prints the section letter where the ptype belongs. The fix is one identifier in model/model.go's writeString helper, and .jeffy/probes/frontend already holds the failing check. Note that model/model.go is declared by .jeffy/probes/enforcer-enforce/paths, so that battery must be re-run and the enforcer-enforce row re-recorded in the same iteration.
- Then the map: nineteen rows unswept. Every red battery below already carries the failing check for its finding, so those rows flip as their findings close.
- Then the Mediums, each with a battery check waiting for it: CAS-11 in management-api, CAS-8 in util-helpers, CAS-12 in config, CAS-16 in persist-cache, CAS-17 in model-constraint. CAS-13 and CAS-5 have no battery check yet - CAS-13 needs a test in management_api_test.go, CAS-5 needs .gitattributes export-ignore entries.
- PLAN.md still carries no `Verify summary pattern` or `Verify count` line, so the wrapper's green line quotes no figure. A declaration will need both filled, and the iteration that fills them should take the count from the wrapper rather than from the suite.
- The management-api row is oversized: sixty-five exported methods behind one checkbox against two for the frontend row. Splitting it by function family would make the rows-swept count mean something.
- Relaunch in a fresh session: context reached 2.8x its opening size by the end of this run.

Learnings: five of the six defects this run fixed or filed as High were invisible at one level of role nesting and visible at two, across four unrelated modules - the constraint engine, the resource-to-users API, and twice in the enforcer's own plumbing. On a library whose whole subject is inheritance, one level deep is the shape every doc example uses and the shape no probe should stop at.

Next: nothing in this run; the budget is spent.

## iter 1/10 | 975fdbdb-175833 | 2026-08-31 | CAS-19 | done

Task: CAS-19 (High, runtime, correctness) - Model.ToText printed the section letter where the ptype belongs, so a model carrying more than one definition in a section serialised to text that did not describe it and lost a definition on reload.

Changed: model/model.go (writeString formats each line with its ptype), model/model_test.go (TestModelToTextKeepsEveryPtype, a round trip over a model with two definitions in each of r, p, e and m), .jeffy/probes/frontend (claims now carries the green summary line, README's discriminating-state paragraph updated to record the defect as fixed), PLAN.md (frontend row swept, enforcer-enforce row re-recorded), BACKLOG.md (CAS-19 deleted), JOURNAL.md.

Checkpoint: 91e526b

Verification: the filed reproduction ran first - .jeffy/probes/frontend through run-probe.sh reported 31/32 with current/model-carries-p2 red, and reports 32/32 after the fix. TestModelToTextKeepsEveryPtype passes, and ten consecutive runs pass, which is the stability check the flaky-assertion lesson earned. Against the unfixed model/model.go, restored from HEAD into a copy-aside and put back afterwards, it fails naming all four sections. enforcer-enforce, the only battery whose paths file declares model/model.go, reports 43/43 through run-probe.sh. check-claims.sh reports 8 checked, 0 mismatched, 0 errored, 0 skipped. Verify gate green through quiet-verify.sh (23s).
Enumeration of the class: writeString is called for r, p, e and m, and the differential run against the unfixed tree reddens on all four - "section r round-tripped with 1 definitions, it had 2" and the same for p, e and m - so the one identifier is the whole class rather than one instance of it. The g and c sections beside it never had the defect; they format the ptype directly and are untouched.
Contract preserved: no signature changed, and a single-definition model is unaffected because ptype equals sec there - which is every model in examples/ and every model the existing TestModelToTest drives, all still green. What changes is a model with a second definition, where the text now names it.
Battery ownership: the diff touches model/model.go and model/model_test.go; `grep -l 'model/model.go' .jeffy/probes/*/paths` names only .jeffy/probes/enforcer-enforce, which was re-run green and whose row is re-recorded at this checkpoint. The frontend row flips to swept in the same edit: its battery was held unswept only because this defect reddened it, and it is now green end to end.

Learnings: a battery left red by a real defect is the acceptance check for that defect already written - running it as the iteration's first command cost one command and proved the finding had not rotted.

Next: the ledger holds no open High, so the queue's next item is the map - eighteen rows unswept of twenty-six after this iteration - and the next iteration is a sweep.

## iter 2/10 | 975fdbdb-175833 | 2026-08-31 | SWEEP | done

Task: the ledger holds no open High, so the map is the top of the queue. Swept two rows that had no instrument at all - model-core and persist-adapters - by writing a known-answer battery for each.

Changed: .jeffy/probes/model-core (new: main.go, run.sh, paths, claims, mutations.sh, README), .jeffy/probes/persist-adapters (new: the same six files), PLAN.md (both rows swept), JOURNAL.md (this entry, and the iteration 1 heading corrected - see below).

Checkpoint: 1b3d9bd

Verification: model-core reports 96/96 and persist-adapters 150/150 through run-probe.sh. check-claims.sh reports 10 checked, 0 mismatched, 0 errored, 0 skipped. Verify gate green through quiet-verify.sh (21s). No product file changed this iteration: `git status --porcelain -- model/ persist/` is empty after every mutation run, and the diff is probe files and state files only.
Both batteries passed on first execution, which certifies nothing, so each was put under discriminating mutations - six for model-core, eight for persist-adapters - applied to the product one at a time and reverted from a copy taken beforehand. Every mutation is recorded in the battery's README and re-runnable through its mutations.sh, which refuses to run when the module it edits is already dirty so it can never discard uncommitted work. The scripts are deliberately not wired into claims: a claim that rewrites product files on every declaration is a claim that can leave the tree broken.
Two of the fourteen mutations did not do their job on the first attempt and both were the mutation rather than the battery, except in one case where it was the battery: model-core's ToText mutation was caught only by a nil-map panic that aborted the run and hid the remaining checks, so the battery now reads assertions through helpers that report a missing definition as `<missing>`; persist-adapters' unparseable-line mutation reddened nothing, because the only unparseable line the battery drove was a comment and the comment guard shields that path before the parse - checks for an unterminated quote and for a line narrower and wider than the rule were added, and the mutation now reddens.
Scores claim only these two rows and nothing wider: correctness None, error handling None, documentation None over model-core and persist-adapters. Eighteen of twenty-six rows were unswept at the start of this iteration and sixteen are unswept after it, so these scores are not the project.
Iteration 1 heading: the run-id was written as 975fdbdb-133000, an HHMMSS I derived by guess rather than reading started_at from the loop state frontmatter, which is 17:58:33Z. The Stop hook named the missing entry and the heading is corrected to 975fdbdb-175833. No other part of that entry was touched.

Learnings: derive the journal run-id from started_at in .claude/jeffy-loop.local.md, never from the wall clock or from memory - the hook matches the heading exactly and a guessed HHMMSS reads to it as an iteration that wrote nothing.

Next: sixteen rows unswept with eight iterations left, so the map still cannot clear this run at two rows an iteration. Five of those rows are held by open Mediums whose batteries already exist and are red - management-api, util-helpers, config, persist-cache, model-constraint - so fixing those findings flips those rows; the other eleven need instruments.

## iter 3/10 | 975fdbdb-175833 | 2026-08-31 | SWEEP | done

Task: no open High at the start of this iteration, so the map was the top of the queue again. Wrote known-answer batteries for two more rows - ai-api and rbac-role-manager. One row flips; ai-api does not, because its battery is red on a real defect.

Changed: .jeffy/probes/ai-api (new: main.go, run.sh, paths, claims reading none, README), .jeffy/probes/rbac-role-manager (new: the same plus mutations.sh), PLAN.md (rbac-role-manager row swept), BACKLOG.md (CAS-20 filed in Now, CAS-21 and CAS-22 filed in Later), JOURNAL.md.

Checkpoint: d09ed6a

Verification: rbac-role-manager reports 100/100 and ai-api 41/44 through run-probe.sh, the three ai-api failures being CAS-20 and nothing else. check-claims.sh reports 11 checked, 0 mismatched, 0 errored, 0 skipped. Verify gate green through quiet-verify.sh (24s). No product file changed this iteration: `git status --porcelain -- model/ persist/ rbac/ ai_api.go` is empty after every mutation run.
rbac-role-manager was put under seven discriminating mutations and each reddens it. One mutation was rejected on the way and is recorded in the battery's README: removing the `level < 0` guard from hasLinkHelper outright makes the manager recurse forever on the cycle these checks drive, so the battery died rather than reporting - that guard is the cycle terminator as well as the depth bound, and a mutation testing the bound has to change the bound rather than delete the terminator.
Two of rbac-role-manager's first-run failures were this battery's wrong expectations rather than defects, which is the third run in a row where that split mattered: GetImplicitRoles seeds its visited set with the name itself, so a cycle does not report the name as one of its own implicit roles; and getDomain takes domains[0] and ignores the rest, which is now pinned by a check and filed as CAS-22 rather than asserted away.
Findings, all reproduced:
- CAS-20 (High): callAIAPI reads the endpoint's response with an unbounded io.ReadAll. Against an httptest server answering with a 64MB body, Explain returns a 67108864-byte string with a nil error and allocates 223MB cumulatively inside the one call, measured as a runtime.MemStats TotalAlloc delta. The envelope classifies that response adversarial, the size is the endpoint's choice, and the 30s timeout does not bound it because a fast link delivers gigabytes inside 30s. The same body is interpolated whole into the error string on the non-200 path.
- CAS-21 (Low): a non-200 whose body is not JSON is reported as "failed to parse response" rather than as the status, because the unmarshal happens before the status check. The parseable-body path reports the status correctly, which is what confines this to the unparseable one.
- CAS-22 (Low): getDomain silently ignores every domain after the first, scored Low because the envelope classifies the Go public API user-error, the interface documents the parameter in the singular, and no in-repo path passes more than one.
Scores claim only the two rows this iteration touched: security High on ai-api (CAS-20), error handling Low on ai-api (CAS-21), correctness Low on rbac-role-manager (CAS-22). Sixteen of twenty-six rows were unswept at the start of this iteration and fifteen after it, so these scores are not the project.

Learnings: a mutation that deletes a guard tests whatever that guard was really for, which is not always what its name suggests - when a mutation kills the battery instead of reddening it, the guard was load-bearing for something else and the mutation needs narrowing to the property under test.

Next: CAS-20 is an open High, so it outranks the map and is the next iteration's task. Fifteen rows unswept with seven iterations left, of which five are held by open Mediums whose batteries already exist and are red.

## iter 4/10 | 975fdbdb-175833 | 2026-08-31 | CAS-20 | done

Task: CAS-20 (High, runtime, security) - callAIAPI read the AI endpoint's response with an unbounded io.ReadAll, so the endpoint rather than this library chose how much memory the calling process allocated. Closed, and the ai-api row flips with it.

Changed: ai_api.go (the response is read through io.LimitReader under a maxAIResponseBytes limit, one byte past it so a truncated body is reported rather than parsed; the non-200 error quotes the body through a new aiSnippet helper bounded by maxAIErrorSnippetBytes instead of embedding it whole; Explain's doc comment states the limit), ai_api_test.go (three tests), .jeffy/probes/ai-api (three more oversize checks, claims now carries the green summary line, README updated), PLAN.md (ai-api row swept), BACKLOG.md (CAS-20 deleted), JOURNAL.md.

Checkpoint: b5e3146

Verification: the filed reproduction ran first - .jeffy/probes/ai-api through run-probe.sh reported 41/44 with the three oversize checks red, and reports 49/49 after the fix. The three new Go tests pass, three consecutive runs pass, and against the pre-fix ai_api.go, restored from HEAD into a copy-aside and put back afterwards, TestExplainRefusesOversizedResponse fails with "an 8MB response should be refused, got a 8388608 byte explanation" and TestExplainDoesNotEchoAnOversizedErrorBody fails with "the error embeds the body: 262226 bytes". TestExplainReadsResponseUnderTheLimit passes against both trees and is stated here as a backward-compatibility guard rather than as evidence of the defect. In the battery the same split holds: five of the six oversize checks redden against the pre-fix tree, oversize/status-named being the exception because the status was already named before the fix. check-claims.sh reports 12 checked, 0 mismatched, 0 errored, 0 skipped. Verify gate green through quiet-verify.sh (23s).
Why a limit rather than a streaming parse: the response is a single JSON object the caller receives whole, so there is nothing to stream into; the fix is to decide the ceiling here rather than let the endpoint decide it. 1 MiB is far above any real completion - the battery drives a 64KiB response through unchanged to pin that the bound refuses the oversized case rather than truncating every response - and far below what an unbounded read costs.
Contract preserved: no signature changed and every previously-succeeding response still succeeds. What changes is a response above the limit, which was previously returned as a multi-megabyte string and is now an error naming the limit, and the non-200 error, which previously carried the whole body and now carries at most 512 bytes of it with a truncation marker. Both are new failure modes on inputs that were never legitimate answers.
CAS-21, the sibling Low on the same function - a non-200 with an unparseable body reports the parse failure rather than the status - was deliberately left open. Fixing it means reordering the status check ahead of the unmarshal, which would also change the message for a non-200 that does carry an error object, and that is its own task rather than a rider on this one.
Battery ownership: the diff touches ai_api.go and ai_api_test.go; `grep -l 'ai_api.go' .jeffy/probes/*/paths` names only .jeffy/probes/ai-api, which is green and whose row is recorded at this checkpoint.

Learnings: when a fix adds a ceiling, drive one input just under it as well as one over it - the over-limit check alone is satisfied by a bound of zero, which would refuse every response the library exists to return.

Next: the ledger holds no open High again, so the map is the top of the queue - fourteen rows unswept of twenty-six with six iterations left.

## iter 5/10 | 975fdbdb-175833 | 2026-08-31 | SWEEP | done

Task: no open High at the start of this iteration, so the map was the top of the queue. Wrote a known-answer battery for enforcer-lifecycle. The row does not flip: the battery is red on a real defect, which is the second time this run that instrumenting a row bought a finding instead of a checkbox.

Changed: .jeffy/probes/enforcer-lifecycle (new: main.go, run.sh, paths, claims reading none, README), BACKLOG.md (CAS-23 filed in Now, CAS-24 filed in Next), JOURNAL.md. No PLAN.md row flipped.

Checkpoint: 34b62fa

Verification: enforcer-lifecycle reports 103/108 through run-probe.sh, the five failures being CAS-23 and nothing else. Verify gate green through quiet-verify.sh. No product file changed this iteration: `git status --porcelain -- enforcer.go internal_api.go` is empty. No Surface inventory row changed state this iteration and the ledger gained three lines, so this is not a stall by either definition.
Findings, both reproduced:
- CAS-23 (High): LoadPolicy, SavePolicy and SetWatcher call an optional collaborator with no nil check. NewEnforcer(model) takes the constructor's documented one-parameter branch into InitWithModelAndAdapter(m, nil), which itself guards `e.adapter != nil` before loading, so the nil adapter is a state the library knowingly creates and then dereferences two methods later. The enumeration was built by provoking every public entry point that can reach an optional collaborator, never by grepping for the calls: fourteen entry points were driven on a nil-adapter enforcer and five collaborators were driven at nil, and exactly three sites lack the guard their siblings have. What holds is as much of the evidence as what fails - the write paths guard through shouldPersist, the filtered loads report an unsupported adapter, Enforce recovers a panic into an error, and ContextEnforcer panics deliberately with a named reason rather than dereferencing nil.
- CAS-24 (Medium, docs): EnableAutoBuildRoleLinks documents itself as governing the rebuild "when a role is added or deleted", and the add and delete paths never consult it. The flag does hold on the load path, which is what makes this a documentation defect rather than a dead flag, and the Consequence is on the line.
Three red checks were this battery's own wrong expectations rather than defects, and all three are recorded in its README because each is a trap the next instrument here will meet. The autoSave one is the most instructive: every adapter in this repository answers AddPolicy with "not implemented" and internal_api.go deliberately tolerates that string, so a check written against a file passes at both values of the flag and certifies nothing. The battery now supplies a recordingAdapter that answers, and the flag is observed as whether the adapter is called at all.
Scores claim only this one row: correctness High and documentation Medium on enforcer-lifecycle. Fourteen of twenty-six rows were unswept at the start of this iteration and fourteen after it.

Learnings: when a documented flag has no observable effect through any collaborator the repository ships, the check needs a collaborator written for the probe - otherwise the flag reads as inert at both values and the row certifies a parameter nobody exercised.

Next: CAS-23 is an open High and outranks the map, so it is the next iteration's task; closing it also flips this row.
# Journal

Append-only. One primary entry per iteration; SALVAGE and ROTATION entries are additional. Never rewrite past entries (filling the current entry's Checkpoint field is completion, not a rewrite).

Heading grammar, exactly (fenced and indented here so this example is never mistaken for an entry by anything that counts or rotates them):

```
  ## iter <i>/<N> | <run-id> | <YYYY-MM-DD> | <task-id or AUDIT or SWEEP or EVALUATOR or RATCHET or WRAPUP or SALVAGE or ROTATION> | <done|blocked|audit|converged|salvage|rotation>
```

Write a real heading at column zero, never indented: the indentation above belongs to the example alone, and an indented heading is invisible to the rotation anchor and to the archive counter, so the entry under it is not counted and not rotated.

A SWEEP entry is an iteration spent sweeping Surface inventory rows and takes status done. SALVAGE entries take status salvage; ROTATION entries take status rotation. An EVALUATOR entry records an evaluator-gate iteration: status audit when the run continues after the verdict, blocked on a terminal REJECT (one with no invocation remaining), converged when that same iteration declares.

run-id is the first 8 characters of the session id, a hyphen, then the HHMMSS of started_at from the loop state frontmatter, so two runs in one session are told apart. Body fields, in order: Task, Changed, Checkpoint (the jeffy checkpoint commit hash, or none with the reason), Verification, Learnings, Next.

The closing entry that declares convergence carries the evaluator verdict in its Verification field: `Evaluator: PASS - <one-line summary>`. `Evaluator: unavailable (<reason>)` is recorded when no sub-agent can be spawned, and it is not a verdict a run declares on: the Stop hook refuses it and the run ends blocked until a relaunch where the gate can run. An earlier EVALUATOR entry records its own verdict the same way and never stands in for the closing one: the Stop hook reads the closing entry alone, so a run that gates early and keeps working re-invokes the gate at the declaration.

Closed tasks are recorded here as one line each (ID, title, closing evidence), because BACKLOG.md deletes them. Rotation: when this file exceeds 500 lines, move all but the last 10 entries to the end of JOURNAL-archive.md, appending to whatever that file already holds and never overwriting it, because the archive accumulates across every rotation and every run; create it only when it does not already exist, and record the rotation as a ROTATION entry.

## iter 6/10 | 975fdbdb-175833 | 2026-08-31 | CAS-23 | done

Task: CAS-23 (High, runtime, correctness) - LoadPolicy, SavePolicy and SetWatcher called an optional collaborator with no nil check, so a documented way of building an enforcer plus a documented method killed the caller's process. Closed class-complete, and the enforcer-lifecycle row flips with it.

Changed: enforcer.go (a named errNoAdapter reported by both adapter paths, the load guard placed at loadPolicyFromAdapter, the save guard in SavePolicy, and SetWatcher returning early on nil with its doc comment stating that nil detaches), enforcer_test.go (two tests, one table-driven over both adapter paths), .jeffy/probes/enforcer-lifecycle (claims now carries the green summary line, README updated), PLAN.md (enforcer-lifecycle row swept), BACKLOG.md (CAS-23 deleted, the class recorded under Settled classes with its enumeration), JOURNAL.md.

Checkpoint: b6387fb

Verification: the filed reproduction ran first - .jeffy/probes/enforcer-lifecycle through run-probe.sh reported 103/108 with the five nil-collaborator checks red, and reports 108/108 after the fix. The two new Go tests pass, three consecutive runs pass, and against the pre-fix enforcer.go, restored from HEAD into a copy-aside and put back afterwards, all three sites fail: "SavePolicy panicked instead of reporting", "LoadPolicy panicked instead of reporting" and "SetWatcher(nil) panicked", each a nil pointer dereference. Battery ownership: the diff touches enforcer.go and enforcer_test.go; `grep -l 'enforcer.go' .jeffy/probes/*/paths` names enforcer-lifecycle and enforcer-enforce, which report 108/108 and 43/43, and both rows are re-recorded at this checkpoint. check-claims.sh reports 13 checked, 0 mismatched, 0 errored, 0 skipped. Verify gate green through quiet-verify.sh (32s).
Class enumeration, re-driven rather than re-read: the same 22 entry points that produced the finding were driven again against the fixed tree, and 0 panic where 3 did before. The guard for the load path went at loadPolicyFromAdapter rather than at LoadPolicy, so SyncedEnforcer.LoadPolicy - the other caller - inherited it without being touched; the enumeration confirms that by driving the synced enforcer's own Load and Save, which now report the same named error.
Contract preserved: no signature changed. LoadPolicy and SavePolicy previously crashed on a nil adapter and now return an error, so no call that used to succeed behaves differently - there was no such call. SetWatcher(nil) previously crashed and now detaches, which is the reading the rest of the file already assumes: every broadcast site guards on e.watcher being non-nil, and the test drives an AddPolicy after detaching to pin that nothing calls back into the absent watcher.
Why a named error rather than a silent no-op on load: InitWithModelAndAdapter deliberately skips the initial load when the adapter is nil, so the library's own view is that there is nothing to load - but a caller who reaches LoadPolicy explicitly has asked for something that cannot happen, and an empty policy returned quietly is the kind of answer the envelope's user-error class exists to rule out.

Learnings: when one root cause has several call sites, put the guard at the boundary they share rather than at each site, then re-drive the enumeration - the synced enforcer was fixed here without being edited, and only the re-driven enumeration showed it.

Next: no open High again, so the map is the top of the queue - thirteen rows unswept of twenty-six with four iterations left, so it cannot clear this run.

## iter 1/10 | 4b8ce05b-183641 | 2026-08-31 | SWEEP | done

Task: no open High at the start of this iteration, so the map was the top of the queue. Wrote known-answer batteries for two unswept rows. One row flips; the other does not, because its battery is red on a real defect, which is the third time on this project that instrumenting a row bought a finding instead of a checkbox.

Changed: .jeffy/probes/enforcer-cached (new: main.go, run.sh, paths, claims carrying the green summary line, README.md), .jeffy/probes/rbac-api-domains (new: the same five files, claims reading none), PLAN.md (enforcer-cached row swept), BACKLOG.md (CAS-25 filed High in Now), JOURNAL.md. No product file changed.

Checkpoint: 68e3812

Verification: enforcer-cached reports 229/229 and rbac-api-domains 65/67 through run-probe.sh, the two rbac-api-domains failures being CAS-25 and nothing else. check-claims.sh reports 14 checked, 0 mismatched, 0 errored, 0 skipped. Verify gate green through quiet-verify.sh (22s). No product file changed this iteration: `git status --porcelain` lists only paths under .jeffy/ and the state files, so the diff is probe files and state files only. One Surface inventory row changed state and the ledger gained a line, so this is not a stall by either definition.

enforcer-cached was green on its first execution, which certifies nothing, so three mutations were driven against copy-asides and reverted: dropping the invalidation wiring in both wrappers reports 103/229, making EnableCache inert reports 227/229, and dropping the key separator reports 225/229. The first is the one that matters - it is exactly the defect the type's doc comment promises is absent, and it reddens the invalidation table across both wrappers rather than a single check. The battery's central assertion is differential rather than absence-of-badness: after every mutation the cached answer must equal the embedded uncached enforcer's answer for the same request. That alone is satisfied by a cache that never stores anything, so the hit checks pin the other side through a recording cache counting Get, Set and Clear, and only a cache that genuinely answers and is genuinely dropped satisfies both. EnableCache and SetExpireTime have no observable effect through any cache this repository ships, so both are observed through that recording collaborator.

Finding, reproduced:
- CAS-25 (High): DeleteDomains with no argument is documented to delete all domains and skips every domain carrying no grouping rule. The enumeration was built by provoking the failure at both sites that expand the empty argument list, never by grepping for the calls they make: Enforcer.DeleteDomains and ContextEnforcer.DeleteDomainsCtx both report true with a nil error, both leave the p rules of a grouping-free domain in the policy, and Enforce still grants that domain's access afterwards. The context site needed a ContextAdapter written for the reproduction, because this module ships none - NewContextEnforcer refuses to build without one. What holds is as much of the evidence as what fails: naming the domains explicitly works at both sites, which is what places the defect in the enumeration behind the empty argument list rather than in the per-domain delete.

The rbac-api-domains battery seeds a domain reached only by p rules for exactly this reason. A battery seeded only with tenants that use RBAC cannot see the defect, because every domain it holds is one the role manager already knows - and a multi-tenant policy where some tenant grants access directly, with no role, is ordinary rather than exotic.

Scores claim only the two rows this iteration touched: correctness High on rbac-api-domains (CAS-25), correctness None on enforcer-cached. Thirteen of twenty-six rows were unswept at the start of this iteration and twelve after it, so these scores are not the project.

Learnings: when a delete takes its work list from an index built by a different subsystem than the one holding the data, seed the probe with an item the index cannot see - the role manager knows only domains that carry a grouping rule, and every tenant in a naively seeded policy is one it knows.

Next: CAS-25 is an open High, so it outranks the map and is the next iteration's task; closing it also flips the rbac-api-domains row. PLAN.md still carries no `Verify summary pattern` and no `Verify count` line, noted once in the previous run and still unfilled, so the wrapper's green line quotes no figure and a declaration has no measured total to rest on.

## iter 2/10 | 4b8ce05b-183641 | 2026-08-31 | CAS-25 | done

Task: CAS-25 (High, runtime, correctness) - DeleteDomains with no argument was documented to delete all domains and skipped every domain carrying no grouping rule, so a tenant's access grants survived a call that reported success. Closed class-complete, and the rbac-api-domains row flips with it.

Changed: rbac_api_with_domains.go (GetAllDomains returns the union of the role manager's domains and the domains the policy names, guarded by the p section's domain field index so a model without one is unchanged; the doc comment states the union and why the two sets differ), rbac_api_with_domains_test.go (four tests), .jeffy/probes/rbac-api-domains (two checks updated to the new contract, one guard added, claims now carries the green summary line, README updated), BACKLOG.md (CAS-25 deleted, the class recorded under Settled classes with its enumeration), JOURNAL.md, PLAN.md (rbac-api-domains row swept, one Lesson).

Checkpoint: 504f913

Verification: the filed reproduction ran first - .jeffy/probes/rbac-api-domains through run-probe.sh reported 65/67 with the two deleteDomains checks red, and reports 69/69 after the fix. The four new Go tests pass, and against the pre-fix rbac_api_with_domains.go, restored from HEAD into a copy-aside and put back afterwards, three of them fail: GetAllDomains answers [tenantA] where [tenantA tenantB] is required, and both DeleteDomains and DeleteDomainsCtx report "left policy rules behind: [[dave tenantB secret read]]" followed by dave still reaching tenantB. TestGetAllDomainsUnchangedWithoutDomainField passes against both trees and is stated here as a backward-compatibility guard rather than as evidence of the defect. Battery ownership: the diff touches rbac_api_with_domains.go and rbac_api_with_domains_test.go; `grep -l 'rbac_api_with_domains.go' .jeffy/probes/*/paths` names only rbac-api-domains, whose row is re-recorded at this checkpoint. check-claims.sh reports 15 checked, 0 mismatched, 0 errored, 0 skipped. Verify gate green through quiet-verify.sh (22s). The example policy files are untouched: `git status --porcelain examples/` is empty, which matters because the context test drives a file-adapter enforcer and an adapter that accepted AddPolicy would have rewritten a fixture.

Class enumeration, driven rather than grepped: both sites that expand an empty argument list were provoked against a policy holding one domain granted through a role and one granted only by policy rules, and both left the direct grant in force before the fix and remove it after. The guard went at GetAllDomains rather than at either site, so ContextEnforcer.DeleteDomainsCtx was fixed without being edited - the same shape as CAS-23, and again only the re-driven enumeration showed it.

Why the union rather than a policy-only enumeration inside DeleteDomains: GetAllDomains documents itself as returning all domains, so the under-reporting is that method's own defect and not only its caller's problem; fixing it there answers the documentation and both callers at once. The role manager was checked and not blamed - a policy loaded with EnableAutoBuildRoleLinks off still leaves the role manager holding its grouping domains, so the missing half is the policy's alone and the fix adds exactly that half.

Contract preserved: no signature changed. GetAllDomains returns a superset of what it returned before, and the added elements are domains the policy names, so no caller that read a domain from this list stops seeing it. A model whose policy definition carries no domain field takes the early return and its answer is byte-identical, which the new guard pins at exactly [""] rather than at [] - fmt prints those two identically, and the obvious form of that check would have certified nothing.

Learnings: when a check's expected value is an empty or one-element collection, print its length and quote its elements - fmt renders a slice holding one empty string exactly as it renders an empty slice, and a guard written the obvious way passes at both.

Next: no open High again, so the map is the top of the queue - eleven rows unswept of twenty-six with eight iterations left, of which five are held by open Mediums whose batteries already exist and are red.

## iter 3/10 | 4b8ce05b-183641 | 2026-08-31 | SWEEP | done

Task: no open High at the start of this iteration, so the map was the top of the queue. Wrote known-answer batteries for two unswept rows. Neither row flips: both batteries are red on real defects, which is now the fourth and fifth time on this project that instrumenting a row bought a finding instead of a checkbox.

Changed: .jeffy/probes/enforcer-rolemanager (new: main.go, run.sh, paths, claims reading none, README.md), .jeffy/probes/enforcer-distributed (the same five files), BACKLOG.md (CAS-26 and CAS-27 filed High in Now), JOURNAL.md. No product file changed and no PLAN.md row flipped.

Checkpoint: 78fd88a

Verification: enforcer-rolemanager reports 58/60 and enforcer-distributed 54/56 through run-probe.sh, and the four failures across them are CAS-26 and CAS-27 and nothing else. check-claims.sh reports 15 checked, 0 mismatched, 0 errored, 0 skipped. Verify gate green through quiet-verify.sh (20s). No product file changed this iteration: `git status --porcelain` lists only BACKLOG.md and the two new probe directories. No Surface inventory row changed state, but the ledger gained two lines, so this is not a stall.

Findings, both reproduced:
- CAS-26 (High): SetRoleManager stores a manager the enforcer does not decide through. The two failing checks alone were consistent with a stale decision cache, so the discriminating reproduction was a role manager that answers every HasLink true, installed over a policy where the subject holds no role: the decision stays false, that manager is consulted 0 times, and GetRoleManager returns it. The getter and the decision path disagree, and only the call count says which one is lying. The consequence is a stale grant rather than a stale denial - an operator installing a depth-1 manager to cut transitive inheritance keeps the transitive grant.
- CAS-27 (High): UpdateFilteredPoliciesSelf sources the rules to replace only from an UpdatableAdapter, which is the CAS-9 defect at a sibling site that fix never reached. Both branches were driven and both fail, differently: nil or false shouldPersist turns the update into an insert that reports false, while true plus the file adapter returns "not implemented" verbatim and applies nothing, where the fixed sibling tolerates that exact string.

What the second finding says about the first fix is the part worth keeping: CAS-9 was closed with a fallback added to internal_api.go and a comment naming precisely the adapters that make the fallback necessary, and the identical code in enforcer_distributed.go was never enumerated. The class was real and the fix was right; only its extent was assumed rather than derived.

Scores claim only the two rows this iteration touched: correctness High on enforcer-rolemanager (CAS-26), correctness High on enforcer-distributed (CAS-27). Eleven of twenty-six rows were unswept at the start of this iteration and eleven after it, so these scores are not the project.

Learnings: when a check fails in a way a cache would also explain, install a collaborator that counts its own calls before filing - "the new object is ignored" and "the old answer was remembered" produce the same wrong value and want different fixes.

Next: CAS-26 and CAS-27 are open Highs and outrank the map, one per iteration; closing them also flips their two rows. Eleven rows unswept of twenty-six with seven iterations left, five of them held by open Mediums whose batteries already exist and are red, so the map cannot clear this run.

## iter 4/10 | 4b8ce05b-183641 | 2026-08-31 | CAS-26 | done

Task: CAS-26 (High, runtime, correctness) - SetRoleManager stored a role manager the enforcer did not decide through, so an application installing its own role manager kept getting the previous manager's answers while the getter reported the new one. Closed class-complete, and the enforcer-rolemanager row flips with it.

Changed: enforcer.go (SetNamedRoleManager re-points the role definition's own RM field as well as rmMap, SetRoleManager delegates to it so the two cannot drift, and both doc comments state when the manager takes effect and that it arrives holding no links), enforcer_test.go (three tests and a counting role manager), .jeffy/probes/enforcer-rolemanager (claims now carries the green summary line, README updated), BACKLOG.md (CAS-26 deleted, the class recorded under Settled classes with its enumeration), JOURNAL.md, PLAN.md (enforcer-rolemanager row swept, two rows re-recorded).

Checkpoint: b6ffad5

Verification: the filed reproduction ran first - .jeffy/probes/enforcer-rolemanager through run-probe.sh reported 58/60 with the two setter checks red, and reports 60/60 after the fix. The three new Go tests pass, and against the pre-fix enforcer.go, restored from HEAD into a copy-aside and put back afterwards, all three fail: "the request was not decided through the manager just installed", "the installed role manager was never consulted", "the named manager did not decide the request: allowed=false, consulted 0 times", and "the replaced role manager still resolved the chain after it was swapped out". Battery ownership: the diff touches enforcer.go and enforcer_test.go; `grep -l 'enforcer.go' .jeffy/probes/*/paths` names enforcer-lifecycle, enforcer-enforce and enforcer-rolemanager, which report 108/108, 43/43 and 60/60, and all three rows are re-recorded at this checkpoint. check-claims.sh reports 16 checked, 0 mismatched, 0 errored, 0 skipped. Verify gate green through quiet-verify.sh (23s).

One test had to be rebuilt before it was evidence of anything. TestSetRoleManagerHonoursAStricterManager originally called BuildRoleLinks between the swap and the request, and passed against the unfixed tree - the rebuild is exactly the workaround that had been hiding the defect, so the test proved nothing. Reading the decision before any rebuild is what makes it discriminating, and the rebuilt version now also pins that depth 1 still resolves one level, so the manager is observably narrowed rather than merely empty.

Why the setter does not rebuild the links itself: it cannot report the failure a rebuild might hit without changing a signature that IEnforcer and SyncedEnforcer both carry, and the interval between installing a manager and populating it is fail-closed this way - an empty manager sees no roles - where the defect was fail-open, answering from the manager the caller had just replaced. The two battery checks hold both halves: the decision must go false the moment an empty manager is installed, and BuildRoleLinks must bring it back. A fix that rebuilt on the caller's behalf would satisfy the second while hiding the first.

Contract preserved: no signature changed and no previously-correct call behaves differently. Both in-repo call sites rebuild or reload right after the swap - model_test.go through LoadPolicy, rbac_api_test.go through the incremental build that AddRoleForUser performs - so both were already getting the new manager and are unaffected, which is also why the existing suite never caught this. What changes is the window between the two calls, which used to answer from the replaced manager and now answers from the installed one.

Learnings: a test that reproduces a defect must be read against the workaround that hid it - if the test performs that workaround itself, it passes on the broken tree and certifies nothing.

Next: CAS-27 is the remaining open High and is the next iteration's task; closing it also flips the enforcer-distributed row. Ten rows unswept of twenty-six with six iterations left.

## iter 5/10 | 4b8ce05b-183641 | 2026-08-31 | CAS-27 | done

Task: CAS-27 (High, runtime, correctness) - UpdateFilteredPoliciesSelf took the rules it was meant to replace only from an UpdatableAdapter, so on every node a dispatcher calls the update degraded into an insert and the rules the caller asked to replace stayed in force. Closed class-complete with CAS-9, and the enforcer-distributed row flips with it.

Changed: enforcer_distributed.go (the declined-adapter error is tolerated rather than returned, and the rules to replace fall back to the model's own filtered read when no adapter supplies them), enforcer_distributed_test.go (new file: four tests across both branches of shouldPersist plus a direct comparison against the non-distributed sibling), .jeffy/probes/enforcer-distributed (claims now carries the green summary line, README updated), BACKLOG.md (CAS-27 deleted, the class recorded under Settled classes with its enumeration, CAS-13 widened to name both sites), JOURNAL.md, PLAN.md (enforcer-distributed row swept).

Checkpoint: c2c5114

Verification: the filed reproduction ran first - .jeffy/probes/enforcer-distributed through run-probe.sh reported 54/56 with the two updateFiltered checks red, and reports 56/56 after the fix. The four new Go tests pass, and against the pre-fix enforcer_distributed.go, restored from HEAD into a copy-aside and put back afterwards, all four fail, each on a different face of the defect: both shouldPersist subtests report "the update replaced rules but reported no change" and "the revoked grant is still in force: true", the declining-adapter test fails with the bare error "not implemented", and the comparison test reports the distributed path leaving four rules where the plain enforcer left two. Battery ownership: the diff touches enforcer_distributed.go and enforcer_distributed_test.go; `grep -l` over the probes' paths files names only enforcer-distributed, which reports 56/56 and whose row is recorded at this checkpoint. check-claims.sh reports 17 checked, 0 mismatched, 0 errored, 0 skipped. Verify gate green through quiet-verify.sh (22s).

The comparison test is the part meant to outlive this fix. The two paths diverged because nothing in the suite ever asked them the same question, so TestUpdateFilteredPoliciesSelfMatchesTheSibling drives one filtered update through each and compares the resulting policies directly - a future edit to either path that does not reach the other now fails rather than waits for a battery to be written.

Contract preserved: no signature changed. Every call that previously succeeded still returns the same answer, because the branch that changed is the one that previously either applied nothing and returned "not implemented" or applied a partial change and reported false. What a caller loses is the raw "not implemented" error, which named an adapter's declined capability rather than anything the caller did wrong.

CAS-13 was widened rather than left alone. Filed against the plain site only, it turns out to describe both: after this fix, a filter matching nothing reports false at both sites while both hold the added rule and enforce it, driven and compared this iteration. The CAS-27 fix neither introduced nor changed that - the distributed site reported false on a filter matching nothing before it too - so the line now names both sites and its acceptance asks for a test at each.

One divergence between the two paths is deliberately left standing and recorded in the battery's README rather than fixed: the sibling normalises an oldRules row that a third-party adapter returned carrying its ptype, and the distributed path does not. No adapter in this repository returns that shape, so nothing here can drive it, and adding the branch would have meant shipping untested code on the strength of a symmetry argument.

Learnings: when two code paths are meant to answer alike, the regression test is a direct comparison of their outputs, not two independent assertions - independent assertions drift apart exactly as the code did.

Next: no open High and no open Medium above the map, so the map is the top of the queue - ten rows unswept of twenty-six with five iterations left, five of them held by open Mediums whose batteries already exist and are red, so the map cannot clear this run.

## iter 6/10 | 4b8ce05b-183641 | 2026-08-31 | SWEEP | done

Task: no open High at the start of this iteration, so the map was the top of the queue. Wrote known-answer batteries for two unswept rows and flipped both. Neither found a defect, which is the first sweep this run that bought checkboxes rather than findings.

Changed: .jeffy/probes/enforcer-synced (new: main.go, run.sh, paths, claims carrying the green summary line, README.md), .jeffy/probes/enforcer-context (the same five files), PLAN.md (both rows swept), JOURNAL.md. No product file changed.

Checkpoint: 9002aff

Verification: enforcer-synced reports 80/80 and enforcer-context 71/71 through run-probe.sh. check-claims.sh reports 19 checked, 0 mismatched, 0 errored, 0 skipped. Verify gate green through quiet-verify.sh (24s). No product file changed this iteration: `git status --porcelain` lists only the two new probe directories. Two Surface inventory rows changed state, so this is not a stall; no ledger item changed.

Both surfaces are delegation layers, so both batteries are differential: every operation runs against a plain enforcer and against the wrapper, and the two must return the same value and leave the same policy and decisions behind. That catches the defect this shape has - delegating to the wrong underlying method - without re-deriving a hundred expected values that would only restate the plain enforcer's own batteries. Because two paths can agree on a wrong answer, hand-written known answers over a two-level hierarchy anchor each differential rather than leaving agreement as the only evidence.

Each battery then drives what its wrapper exists for and its sibling cannot. For enforcer-synced that is the lock and the auto-load goroutine, and run.sh carries -race: the eight goroutines mixing reads and writes pass under any locking discipline without it, and the race detector is the only thing there that grades the wrapper's purpose. StopAutoLoadPolicy is driven at both observable outcomes, the flag going false and a later file change not being picked up, because a stop that only flips the bool leaves the goroutine reloading. For enforcer-context it is that a cancelled context leaves the in-memory policy unmoved - a persist failure that still applies locally leaves the enforcer deciding from state the store never accepted.

Both batteries were green on first execution, so each was mutated three times, once per property, and every mutation reddened the intended checks: for enforcer-synced, wrong delegation 61/80, an inert StopAutoLoadPolicy 78/80, and a missing lock which kills the probe with WARNING: DATA RACE before its summary line; for enforcer-context, wrong delegation 68/71, a dropped context 55/71, and applying before persisting 66/71 on exactly the policy-untouched checks.

The enforcer-context battery was red on its first run at 62/68 and none of it was a defect. The batch entry points appeared to ignore a cancelled context, because that path guards on persist.ContextBatchAdapter and the probe's adapter implemented only ContextAdapter, so persistence was skipped and no adapter call existed to carry the context. The second attempt at a deliberately capability-less adapter was wrong the same way: it embedded the recording adapter to reuse its methods and therefore inherited the batch methods and satisfied the batch interface after all. Both corrections are recorded in that battery's README, and the declined-capability case is now a checked behaviour rather than an assumption.

Scores claim only the two rows this iteration touched: correctness None on enforcer-synced, correctness None on enforcer-context. Nine of twenty-six rows were unswept at the start of this iteration and seven after it, so these scores are not the project.

Learnings: a probe type meant to lack a capability must not embed one that has it - embedding inherits the methods and the type satisfies the interface it was written to fail.

Next: seven rows unswept of twenty-six with four iterations left. Two of them need new batteries, internal-api and transactions; the other five are held by open Mediums whose batteries already exist and are red, so the map cannot clear this run.

## iter 7/10 | 4b8ce05b-183641 | 2026-08-31 | SWEEP | done

Task: no open High at the start of this iteration, so the map was the top of the queue. Wrote a known-answer battery for the transactions row. The row does not flip: the battery is red on a real defect, and a second finding is visible in what the battery cannot drive rather than in what fails.

Changed: .jeffy/probes/transactions (new: main.go, run.sh, paths, claims reading none, README.md), BACKLOG.md (CAS-29 filed High in Now, CAS-28 filed Low in Later), JOURNAL.md. No product file changed and no PLAN.md row flipped.

Checkpoint: b9e99bb

Verification: transactions reports 70/74 through run-probe.sh and the four failures are CAS-29 and nothing else. check-claims.sh reports 19 checked, 0 mismatched, 0 errored, 0 skipped. Verify gate green through quiet-verify.sh (20s). No product file changed this iteration: `git status --porcelain` lists only BACKLOG.md and the new probe directory. No Surface inventory row changed state, but the ledger gained two lines, so this is not a stall.

Findings, both reproduced:
- CAS-29 (High): the conflict detector never runs against a change made through the ordinary enforcer API. modelVersion is incremented in exactly one place, at the end of a successful Commit, so a direct write leaves the version untouched, the check in front of DetectConflicts sees no change, and the detector is skipped whole. What makes this a finding rather than a reading of the source is that the battery drives each conflict shape twice, changing only which API the competing writer used: with a competing transaction both shapes are refused by name, and with a competing direct write both commit. The update case carries the consequence - a transaction replacing alice/data1/read with alice/reports/read, while that rule is revoked directly underneath it, commits and leaves alice/reports/read enforcing true.
- CAS-28 (Low): GetTransaction and IsTransactionActive take an id no caller outside the package can obtain, because Transaction exposes 38 exported methods and none returns it. Scored Low with the rationale on the line: the envelope classifies the Go public API user-error and the consequence is an unreachable API rather than a wrong answer.

CAS-28 was found by the battery failing to be writable rather than by a check failing. The registry section was drafted with a helper that recovered the id, and there was no way to write that helper; the stub returned an empty string and would have made two checks pass against nothing. That is worth recording as a shape: an instrument that cannot be written honestly is itself evidence about the surface.

Scores claim only the one row this iteration touched: correctness High on transactions (CAS-29), documentation Low on transactions (CAS-28). Seven of twenty-six rows were unswept at the start of this iteration and seven after it, so these scores are not the project.

Learnings: when a mechanism is meant to detect concurrent change, drive it once per kind of writer that can make that change - the detector here is correct and complete for the writer it was tested against, and blind to the other one.

Next: CAS-29 is an open High and outranks the map, so it is the next iteration's task; closing it also flips the transactions row. Seven rows unswept of twenty-six with three iterations left, of which internal-api is the last needing a new battery and five are held by open Mediums.

## iter 8/10 | 4b8ce05b-183641 | 2026-08-31 | CAS-29 | done

Task: CAS-29 (High, runtime, correctness) - the transaction conflict detector never ran against a change made through the ordinary enforcer API, so a transaction committed over a concurrent direct write and its optimistic locking silently did not apply. Closed class-complete, and the transactions row flips with it.

Changed: enforcer_transactional.go (modelVersion is advanced from the embedded Enforcer's policy-changed callback as well as from Commit, with both the reason and the reason Commit still advances it separately recorded on the new method), transaction_test.go (two tests, one of them four paired subtests), .jeffy/probes/transactions (claims now carries the green summary line, README updated), BACKLOG.md (CAS-29 deleted, the class recorded under Settled classes with its enumeration), JOURNAL.md, PLAN.md (transactions row swept).

Checkpoint: 22071bb

Verification: the filed reproduction ran first - .jeffy/probes/transactions through run-probe.sh reported 70/74 with the four direct-write conflict checks red, and reports 74/74 after the fix. The new Go tests pass, and against the pre-fix enforcer_transactional.go, restored from HEAD into a copy-aside and put back afterwards, exactly the two direct-write subtests fail, naming the two conflict reasons the detector never reached. Battery ownership: the diff touches enforcer_transactional.go and transaction_test.go; `grep -l 'enforcer_transactional.go' .jeffy/probes/*/paths` names only transactions, whose row is recorded at this checkpoint. check-claims.sh reports 20 checked, 0 mismatched, 0 errored, 0 skipped. Verify gate green through quiet-verify.sh (23s).

The fix went at the callback the Enforcer already had rather than at each mutation: policyChangedCallback fires after every change to the model in memory, which is the same hook CachedEnforcer uses to drop its cache, so one line covers every write path including ones added later. Commit still advances the version itself, because its apply path replaces the model directly and never goes through that callback - the new method says so, since the two sites look redundant and are not.

The guard matters as much as the fix here. Advancing the version on every write would satisfy the whole conflict section by turning every concurrent write into a conflict, which is a different defect wearing the same green, so TestConflictDetectionAllowsUnrelatedDirectWrites and the battery's unrelated-change checks require a non-colliding direct write to still commit and both its rules to be in force afterwards.

Contract preserved: no signature changed and no previously-correct call behaves differently. What changes is a commit that used to succeed while the detector was skipped; that commit is now refused with the reason the detector already had a name for. TestTransactionKeepsChangesMadeOutsideIt, the existing test that pins a direct write surviving a commit, is unaffected and stays green because its buffered operation is an add, and adds never conflict by the detector's own rule - the version now advances in that test too, so the detector runs and finds nothing.

Learnings: when a fix widens what a mechanism notices, add the check that it does not now notice everything - a detector that fires on every event passes every test written only from the missed case.

Next: no open High and no open Medium above the map, so the map is the top of the queue - six rows unswept of twenty-six with two iterations left, of which internal-api is the last needing a new battery and five are held by open Mediums, so the map cannot clear this run.

## iter 1/10 | 10a2e20f-193132 | 2026-08-31 | SWEEP | done

Task: no open High at the start of this iteration and no stale row - every swept row's battery paths file was checked against `git diff --name-only <recorded commit> HEAD` and none of the twenty came back changed - so the map was the top of the queue. Wrote a known-answer battery for the internal-api row, the last unswept row that needed a new instrument rather than a fix. The row does not flip: the battery is red on a real defect.

Changed: .jeffy/probes/internal-api (new: main.go, run.sh, paths, claims reading none, README.md, and ptype-enumeration/ with its own main.go and run.sh), BACKLOG.md (CAS-30 filed High in Now), JOURNAL.md. No product file changed and no PLAN.md row flipped.

Checkpoint: 4e32023

Verification: internal-api reports 227/230 through run-probe.sh and the three failures are CAS-30 and nothing else. check-claims.sh reports 20 checked, 0 mismatched, 0 errored, 0 skipped. Verify gate green through quiet-verify.sh (20s). No product file changed this iteration: `git status --porcelain` lists only BACKLOG.md and the new probe directory, and `git diff --stat` over the tracked product files is empty after every mutation run. No Surface inventory row changed state, but the ledger gained a line, so this is not a stall.

Nothing in internal_api.go is exported except GetFieldIndex and SetFieldIndex, so the battery drives the layer through the public edit methods and grades what lives in it rather than in the callers that plumb arguments down: whether the adapter is consulted at all, which optional adapter capability a batched or updating edit requires, what a persistence failure leaves behind, which watcher method each entry point selects, whether a dispatcher takes the edit instead of the local model, whether a constraint refusal happens before any of the write, and whether role links move with a grouping edit. The three adapter tiers and the three watcher tiers are written out separately rather than embedded, which is the lesson the enforcer-context battery paid for.

The battery was green at 229/229 on its first correct execution, so every property group was confirmed against a deliberate mutation of internal_api.go before the row was considered at all. Ten mutations were applied one at a time, run, and reverted; each reddened its intended group and nothing else: shouldPersist ignoring autoSave reddened 1 persist check, dropping the "not implemented" tolerance 2 tolerate checks, persisting after the model change instead of before 4 tolerate checks, persisting a batch rule by rule through the plain Adapter 3 capability checks, skipping the duplicate check 3 noop checks, always calling Update() instead of the WatcherEx method 1 notify check, validating constraints after the write 15 constraint checks, skipping the incremental role links on removal 3 links checks, ignoring the dispatcher 3 dispatch checks, and making SetFieldIndex store nothing 6 field checks. The last of those is wider than its property - removing the write also removes the map dereference - and that is recorded in the battery's README rather than narrowed away, because the mutation still reddened the checks it was aimed at.

Its first run was red at 223/229 and none of it was a defect: six checks matched the constraint refusal message as a substring of the wrong shape. The error is a *ConstraintViolationError carrying the key as a field, so those checks now pull the key out with errors.As and compare it, which is a known answer rather than a substring.

Finding, reproduced: CAS-30 (High) - a ptype the model does not define crashes the process at seven public entry points, where the rest of the same family answer with an error. The enumeration was built by provoking a failure at every public entry point that takes a ptype, never by grepping for the lookups, because a site that crashes without naming a map is invisible to a name scan; that probe is committed at .jeffy/probes/internal-api/ptype-enumeration and names GetAllNamedSubjects, GetAllNamedObjects, GetAllNamedActions, GetFieldIndex, SetFieldIndex, GetFilteredNamedPolicyWithMatcher and GetNamedImplicitPermissionsForUser as panicking while every other entry point it drives answers with an error or an empty result. Scored High rather than Medium: the consequence is a nil pointer dereference killing the embedding application's process, the Operating envelope classifies the Go public API user-error and says a wrong value there deserves a clear failure message, and the same API's own siblings establish that an error is the intended answer.

The battery's two field checks about an unknown ptype were first written to assert the panic, which would have pinned the defect as the contract. They now assert the behaviour the siblings set - no panic, and an error from GetFieldIndex - which is what leaves the battery red and the row unswept.

One branch is out of the battery's reach and is recorded in its README rather than silently skipped: updateFilteredPoliciesWithoutNotify carries a sec == "g" arm for constraint validation and role links, and its one caller in management_api.go passes "p", so nothing public reaches it.

Learnings: a battery that pins the behaviour it observes rather than the behaviour the surface's own siblings establish will certify a crash as the contract; when one entry point in a family answers differently from the rest, the family is the known answer.

Next: CAS-30 is an open High and outranks the map, so it is the next iteration's task; closing it also flips the internal-api row and, since the fix touches management_api.go and rbac_api.go, re-sweeps the management-api and rbac-api rows around it. Six rows unswept of twenty-six with nine iterations left; the other five are held by open Mediums whose batteries already exist and are red.

## iter 1/10 | 10a2e20f-193132 | 2026-08-31 | ROTATION | rotation

Task: JOURNAL.md stood at 663 lines after this iteration's entry, past the 500-line threshold, so all but the last 10 entries were moved to JOURNAL-archive.md.

Changed: JOURNAL.md (25 entries removed, preamble and the last 10 entries kept), JOURNAL-archive.md (new, holding those 25 entries oldest first).

Checkpoint: 4e32023

Verification: 10 entries remain in JOURNAL.md and 25 are in JOURNAL-archive.md, which is 35 - the 34 entries the file held before this iteration plus this iteration's SWEEP entry. The split was taken only on lines beginning `## iter` followed by a digit, so the heading-grammar example in the preamble was neither counted nor moved, and the preamble stayed with JOURNAL.md.

Learnings: none.

Next: unchanged from the SWEEP entry above.

## iter 2/10 | 10a2e20f-193132 | 2026-08-31 | CAS-30 | done

Task: CAS-30 (High, runtime, error handling) - a ptype the model does not define crashed the process at seven public entry points, where the rest of the same family answered with an error. Closed class-complete, and the internal-api row flips with it.

Changed: model/model.go (GetFieldIndex resolves the policy type through GetAssertion), internal_api.go (SetFieldIndex does the same and ignores a ptype it cannot resolve), management_api.go (GetFilteredNamedPolicyWithMatcher resolves the assertion once at the top and reads it instead of re-indexing the model four times), rbac_api.go (GetNamedImplicitPermissionsForUser resolves the assertion and keeps the domain-index error raised only where a domain was passed), management_api_test.go and model/model_test.go (three tests, one of them seven paired subtests), .jeffy/probes/internal-api (claims now carries the green summary line, README updated), BACKLOG.md (CAS-30 deleted, the class recorded under Settled classes with its enumeration), PLAN.md (internal-api row swept, three re-recorded rows, two Lessons), JOURNAL.md.

Checkpoint: 8e20e00

Verification: the filed reproduction ran first - .jeffy/probes/internal-api/ptype-enumeration through run-probe.sh named seven panicking entry points, and names none after the fix; the internal-api battery reported 227/230 with the three unknown-ptype checks red and reports 230/230. The new Go tests pass, and against the pre-fix model/model.go, internal_api.go, management_api.go and rbac_api.go, restored from HEAD into a copy-aside and put back afterwards, all seven subtests of TestUndefinedPtypeIsReportedNotFatal fail, each naming its own site with "runtime error: invalid memory address or nil pointer dereference", and TestGetFieldIndexUndefinedPtype fails at the boundary. TestDefinedPtypeStillResolves passes against both trees and is stated here as a backward-compatibility guard rather than as evidence of the defect. Battery ownership: the diff touches internal_api.go, management_api.go, rbac_api.go and model/model.go; `grep -l` over the probes' paths files names internal-api, management-api, rbac-api, model-core and enforcer-enforce, which report 230/230, 108/110, 95/95, 96/96 and 43/43 - the two management-api failures are CAS-11 and nothing else, which is why that row stays unswept - and the four rows whose batteries are green are recorded at this checkpoint. check-claims.sh reports 21 checked, 0 mismatched, 0 errored, 0 skipped. Verify gate green through quiet-verify.sh (23s).

The boundary was fixed first and the enumeration re-driven before anything else was touched, which is what made the extent of the class a measurement rather than a reading. Guarding model.GetFieldIndex alone took the count from seven to three: GetAllNamedSubjects, GetAllNamedObjects and GetAllNamedActions all reach an unknown ptype through that one lookup and simply propagate the error it now returns. The three that remained each carried a lookup of their own, and none of them would have been found by grepping for GetFieldIndex.

Contract preserved: no signature changed. Three of the four sites now return the error model.GetAssertion already produced for a missing definition, on an input that previously killed the process, so no previously-correct call behaves differently. SetFieldIndex is the exception worth stating: it returns nothing, so it cannot report, and adding a return value would break every caller in every embedding application. It ignores a ptype it cannot resolve, and its doc comment now says so. TestDefinedPtypeStillResolves is the guard on all four, driving a model with a second policy type so a check written only against "p" would fail there: both ptypes resolve, GetAllNamedSubjects answers over p2, and SetFieldIndex still records an index on a ptype that exists.

The rbac_api.go site needed one more thing than a guard. Its GetFieldIndex error was assigned and then consulted only inside the domain branch, deliberately, because a model with no domain field is not an error for a caller passing no domain. That shape is kept: the assertion error returns immediately, the domain-index error is held in its own variable and still raised only where a domain was actually passed, so a model without a dom field keeps answering the no-domain call.

Learnings: a class enumeration built by provocation prices the boundary fix before it is written - the same probe that filed the finding reported which four sites the boundary closed and which three it did not, and that is a measurement no reading of the source produces.

Next: no open High and no stale row, so the map is the top of the queue - five rows unswept of twenty-six with eight iterations left, and every one of them is held by an open Medium whose battery already exists and is red, so the next iterations are those Mediums: CAS-11 flips management-api, CAS-8 util-helpers, CAS-17 model-constraint, CAS-12 config, CAS-16 persist-cache.

## iter 3/10 | 10a2e20f-193132 | 2026-08-31 | CAS-16 | done

Task: CAS-16 (Medium, runtime, documentation) - cache.Cache documented its survival-time parameter as a time.Time while both implementations asserted time.Duration, so a caller following the interface documentation crashed the process. Closed class-complete, and the persist-cache row flips with it. No open High and no stale row stood above it, and the five unswept rows are each held by an open Medium whose battery already exists and is red, so no row could be evidenced without its fix; this is the first runtime Medium in the ledger and it is one of the five.

Changed: persist/cache/cache.go (the interface comment names time.Duration and a new shared survivalTime helper reads the parameter), persist/cache/default-cache.go and persist/cache/cache_sync.go (both read it through that helper), persist/cache/cache_test.go (new file, one test over both implementations), .jeffy/probes/persist-cache (six new checks, claims now carries the green summary line, README updated), BACKLOG.md (CAS-16 deleted, the class recorded under Settled classes with its enumeration, and the Next section reordered so runtime precedes docs and build-ci as its own rule requires), PLAN.md (persist-cache row swept), JOURNAL.md.

Checkpoint: 9eea551

Verification: the filed reproduction ran first - .jeffy/probes/persist-cache through run-probe.sh reported 52/54 with both documented-extra-type checks panicking, and reports 64/64 after the fix. The new Go test passes, and against the pre-fix persist/cache, restored from HEAD into a copy-aside and put back afterwards, both its subtests fail with the panic itself: "interface conversion: interface {} is time.Time, not time.Duration". Battery ownership: the diff touches persist/cache/cache.go, default-cache.go and cache_sync.go; the only paths file matching any of them is persist-cache, whose row is recorded at this checkpoint, and enforcer-cached was run anyway because it answers from this cache, reporting 229/229. check-claims.sh reports 22 checked, 0 mismatched, 0 errored, 0 skipped. Verify gate green through quiet-verify.sh (23s).

Both halves of the finding were fixed, because either alone leaves the defect. The comment now names time.Duration, which is what the code has always accepted; and the parameter is read through one helper that returns an error naming both the type it wants and the type it got, rather than asserting a value the signature does not constrain. Set already returns an error, so it had a channel to report on and needed no signature change.

The helper is shared deliberately. The two implementations are two copies of one contract, and the failure this shape invites is a fix applied to one of them; the Go test drives both from one table for the same reason. `grep -rnE 'extra\[0\]\.\(|params\[0\]\.\(' --include='*.go' . | grep -v _test | grep -v '/probes/'` finds no other unchecked site in the tree - every remaining hit is the checked `, ok :=` form - so the class is these two sites and is closed.

Contract preserved: no signature changed and no in-repo path behaves differently. CachedEnforcer and CachedSyncedEnforcer pass a time.Duration through SetExpireTime, which is what the code accepted before and accepts now; what changes is that a value of any other type is reported instead of killing the caller.

The battery's own checks were widened with the fix rather than left as they were. "Does not crash" is satisfied by silently ignoring the argument, which is a different defect wearing the same green, so the checks now require the error to name both types, require nothing stored under the refused key, drive a second wrong type so the message reports its argument rather than a constant, and require a valid duration to round-trip after a refusal.

Learnings: a check written as "must not crash" is satisfied by silently swallowing the input; when the fix arrives, widen the check to name what the call must answer, or the battery certifies the next defect.

Next: no open High and no stale row, so the map is the top of the queue - four rows unswept of twenty-six with seven iterations left, each still held by an open Medium whose battery is red: CAS-17 flips model-constraint, CAS-11 flips management-api, CAS-8 flips util-helpers, CAS-12 flips config. CAS-17 is the next runtime Medium in the ledger.

## iter 4/10 | 10a2e20f-193132 | 2026-08-31 | CAS-17 | done

Task: CAS-17 (Medium, runtime, correctness) - a constraint written with an empty value was dropped at load and the model validated clean, so a control the operator wrote was silently absent and nothing distinguished that from a model carrying no constraints at all. Closed class-complete, and the model-constraint row flips with it.

Changed: model/model.go (loadSection returns an error and reports a definition the config carries with no value, loadModelFromConfig propagates it), config/config.go (new HasOption method, which answers the question String cannot), model/model_test.go (two tests, one of them nine subtests), .jeffy/probes/model-constraint (model/model.go added to paths, claims now carries the green summary line, README updated), BACKLOG.md (CAS-17 deleted, the class recorded under Settled classes with its enumeration), PLAN.md (model-constraint row swept, three re-recorded rows, one Lesson), JOURNAL.md.

Checkpoint: c51e200

Verification: the filed reproduction ran first - .jeffy/probes/model-constraint through run-probe.sh reported 30/31 with parse/empty-value red, and reports 31/31 after the fix. The new Go tests pass, and against the pre-fix model/model.go and config/config.go, restored from HEAD into a copy-aside and put back afterwards, all nine subtests of TestEmptyDefinitionIsReported fail - five of them by loading with no error whatsoever, which is the silent discard the finding is about, and four with a message naming the section but not the key. TestSectionEndsWithoutTheKey passes against both trees and is stated here as a backward-compatibility guard rather than as evidence of the defect. Battery ownership: the diff touches model/model.go and config/config.go; the paths files matching them name internal-api, model-core, enforcer-enforce and config, which report 230/230, 96/96, 43/43 and 52/54 - the two config failures are CAS-12 and nothing else, which is why that row stays unswept - and the rows whose batteries are green are recorded at this checkpoint. check-claims.sh reports 23 checked, 0 mismatched, 0 errored, 0 skipped. Verify gate green through quiet-verify.sh (23s).

The first attempt at this fix was wrong and the suite said so, which is worth recording because the reasoning looked sound. The shared boundary for the whole class appeared to be config.Config.write: every section loads through it, and refusing an option with no value there would have reported the line number as well as the key. The verify gate came back red on the config package's own TestGet, which loads a fixture whose [multi4] section resolves a line-continuation chain to an empty value and asserts that String returns "" for it. An empty value is a pinned part of that package's contract, so the boundary refuses the fix rather than the other way round; weakening that test to admit the fix is exactly what the Constraints forbid.

The fix therefore sits one layer up, where the two cases actually differ in consequence. AddDef refuses an empty value and loadSection read that refusal as the end of the section, so an empty definition took itself and every later key in its section with it - an empty c2 dropped c3 and c4 as well. loadSection now asks whether the key was written at all and reports it by name when it was. The question goes to a new HasOption method on the concrete config.Config through an optional type assertion, not through ConfigInterface: adding a method to that interface would break every implementation outside this module, while adding one to the struct breaks nobody, and a config that does not offer it degrades to exactly the old behaviour. That is the same shape this codebase already uses for optional adapter capabilities.

Contract preserved: no signature exported from this module changed, and no well-formed model loads differently - TestSectionEndsWithoutTheKey drives a model with two policy types, two role types and a constraint and requires every one of them to load. What changes is the message a malformed model gets: an empty required definition used to report "missing required sections: policy_definition" and now reports "policy_definition: p has no value", and an empty optional definition used to report nothing at all.

The battery's paths file gained model/model.go with the fix. Its parse/empty-value check is graded by the loader rather than by the constraint algebra, and a paths file that did not say so would let a future change to the loader silence every constraint in a model while this battery sat unrun.

Learnings: before fixing at a shared boundary, run the suite that owns it - a contract the boundary's own tests pin is the boundary refusing the fix, and the layer above is where the cases actually differ.

Next: no open High and no stale row, so the map is the top of the queue - three rows unswept of twenty-six with six iterations left, each held by an open Medium whose battery is red: CAS-13 is the next runtime Medium but flips no row, then CAS-11 flips management-api, CAS-8 flips util-helpers and CAS-12 flips config.

## iter 5/10 | 10a2e20f-193132 | 2026-08-31 | CAS-11 | done

Task: CAS-11 (Medium, runtime, correctness) - the policy store retained the slice the caller passed, so a caller filling one buffer in a loop silently rewrote the rules it had already added. Closed class-complete, and the management-api row flips with it.

Changed: model/policy.go (a storedRule helper, and every path that puts a caller-supplied rule into an assertion takes a copy through it), management_api_test.go (one test, eighteen subtests), .jeffy/probes/management-api (claims now carries the green summary line, README updated), BACKLOG.md (CAS-11 deleted, the class recorded under Settled classes with its enumeration), PLAN.md (management-api row swept, model-policy re-recorded), JOURNAL.md.

Checkpoint: 4584622

Verification: the filed reproduction ran first - .jeffy/probes/management-api through run-probe.sh reported 108/110 with both alias/ checks red, showing the stored rules reading [[bob MUTATED]] and [[carol MUTATED read]], and reports 110/110 after the fix. The new Go test passes, and against the pre-fix model/policy.go, restored from HEAD into a copy-aside and put back afterwards, 16 of its 18 subtests fail. The 2 that pass are AddPolicy and AddNamedPolicy, the pair that already copied; they pass against both trees and are the backward-compatibility side of the same table rather than evidence of the defect. Battery ownership: the diff touches model/policy.go; `grep -l` over the probes' paths files names management-api and model-policy, which report 110/110 and 50/50, and both rows are recorded at this checkpoint. model-core and internal-api were run as well because they read the same store, reporting 96/96 and 230/230. check-claims.sh reports 24 checked, 0 mismatched, 0 errored, 0 skipped. Verify gate green through quiet-verify.sh (32s).

The extent was measured before the fix was written rather than read off the ledger line. The line proposed fixing model.AddPolicy so every entry point would inherit it; driving all eighteen public entry points that hand the model a rule showed sixteen retaining the caller's slice, and the update family was not reachable from AddPolicy at all - UpdatePolicy, UpdatePolicies and the rollback inside UpdatePolicies each store a caller rule of their own. A fix at AddPolicy alone would have turned twelve subtests green and left four red with the ledger line closed.

That is also how the defect survived this long. Enforcer.AddNamedPolicy copies its argument before handing it down, so the one entry point a reader is most likely to check looks correct, and every sibling beside it looks the same from the call site. The fix therefore sits at the store rather than at the entry points: one helper, used at each of the four places an assertion receives a caller-supplied rule, so an entry point added later inherits the copy instead of having to remember it.

Contract preserved: no signature changed and no caller that does not mutate its input behaves differently. What changes is that the store no longer aliases the caller's memory, at the cost of one slice copy per stored rule - the same copy Enforcer.AddNamedPolicy has always made. The persistence path inherits it too, since adapters load through model.AddPolicy, and that matters for the consequence: after SavePolicy and LoadPolicy it was the rewritten rule that persisted, so a caller reusing a buffer lost the grants of every subject but the last.

Learnings: when a ledger line proposes the boundary to fix, drive the enumeration before trusting it - the line here named one function and the class had two more, in a family the named boundary could not reach.

Next: no open High and no stale row, so the map is the top of the queue - two rows unswept of twenty-six with five iterations left, both held by an open Medium whose battery is red: CAS-8 flips util-helpers and CAS-12 flips config. CAS-13 remains the ledger's next runtime Medium but flips no row.

## iter 6/10 | 10a2e20f-193132 | 2026-08-31 | CAS-8 | done

Task: CAS-8 (Medium, runtime, correctness) - util.LRUCache.Put on a key already present re-linked the existing node and never stored the new value, so the cache kept answering with the value the key was first stored with and discarded every later write in silence; the SyncLRUCache wrapper inherited it. Closed class-complete, together with the dead matchingFuncCache field the line named as part of its surface, and the util-helpers row flips with it.

Changed: util/util.go (Put writes the new value onto the node it reuses for the links), rbac/default-role-manager/role_manager.go (the matchingFuncCache field deleted from both types along with the two allocations and the comments naming it), util/util_test.go (one test, two subtests), .jeffy/probes/util-helpers (claims now carries the green summary line, README updated), BACKLOG.md (CAS-8 deleted, the class recorded under Settled classes with its enumeration), PLAN.md (util-helpers row swept, rbac-role-manager re-recorded, one Lesson), JOURNAL.md.

Checkpoint: 0cd054c

Verification: the filed reproduction ran first - .jeffy/probes/util-helpers through run-probe.sh reported 57/58 with lru/overwrite-value red at "got 1, want 2", and reports 58/58 after the fix. The new Go test passes, and against the pre-fix util/util.go, restored from HEAD into a copy-aside and put back afterwards, both its subtests fail on four assertions each, every one of them reading the first value back where a later one was written. Battery ownership: the diff touches util/util.go and rbac/default-role-manager/role_manager.go; the paths files matching them name util-helpers and rbac-role-manager, which report 58/58 and 100/100, and both rows are recorded at this checkpoint. check-claims.sh is re-run below. Verify gate green through quiet-verify.sh (24s).

The dead field was the second half of the line and it was deleted rather than used. `grep -rn 'matchingFuncCache'` showed it declared on RoleManagerImpl and on DomainManager, allocated in each type's Clear, and never read or written anywhere else, so every role manager was allocating a hundred-entry synchronised cache that nothing consulted. Deleting it is what the Constraints ask for over inventing a use, and it removes the only in-repo instance of the defect this task fixed - which is exactly why CAS-8 was scored Medium rather than High: no enforcement decision could be wrong because of it, since the one internal caller never read the cache.

The test's own first draft was wrong about the eviction, not about the overwrite. It expected the key written three times to be evicted at capacity, and the cache evicted a different one, because Get promotes to most-recently-used and the check reads that key just before the Put that forces the eviction. The expectation is now computed from the accesses rather than the insertion order, and it is kept rather than dropped: without it the test would pass on a Put that stored the value and corrupted the list.

Contract preserved: no signature changed. The only behaviour that changes is Put over an existing key, which now stores what it was given; a caller that never overwrites sees the same cache it always had, and the eviction order is pinned by the same test so the fix cannot have bought the value at the list's expense.

Learnings: an LRU check that reads a key before forcing an eviction has promoted it - compute the expected victim from the accesses, not from the insertion order.

Next: no open High and no stale row, so the map is the top of the queue - one row unswept of twenty-six with four iterations left, held by CAS-12, which flips config. After that the ledger holds CAS-13, CAS-24 and CAS-5, three Mediums for three remaining iterations, which leaves no iteration for the closing full audit the declaration requires; this run will end out of budget rather than converged.

## iter 7/10 | 10a2e20f-193132 | 2026-08-31 | CAS-12 | done

Task: CAS-12 (Medium, runtime, correctness) - config.Config accepted a section or option name carrying an uppercase letter and could then never return it, because the parser stored the name as written while get and Set lower-case the whole key. Closed class-complete, and the config row flips with it. That was the last unswept row: the Surface inventory now lists twenty-six swept rows and none unswept.

Changed: config/config.go (AddConfig lower-cases the section and the option), config/config_test.go (one test), .jeffy/probes/config (claims now carries the green summary line, README updated), BACKLOG.md (CAS-12 deleted, the class recorded under Settled classes with its enumeration), PLAN.md (config row swept), JOURNAL.md.

Checkpoint: c665b33

Verification: the filed reproduction ran first - .jeffy/probes/config through run-probe.sh reported 52/54 with both case/mixed-* checks red at "got , want value", and reports 54/54 after the fix. The new Go test passes, and against the pre-fix config/config.go, restored from HEAD into a copy-aside and put back afterwards, it fails on five assertions: all three spellings of the mixed-case key read back empty, and Bool and Int fail their conversions on the empty string that lookup returns. Battery ownership: the diff touches config/config.go; the only paths file matching it is config, whose row is recorded at this checkpoint, and model-core and internal-api were run as well because the model loads through this parser, reporting 96/96 and 230/230. check-claims.sh is re-run below. Verify gate green through quiet-verify.sh (23s).

The fix went at the write rather than at the read. Every write reaches the store through AddConfig - the parser's own write path and the exported Set both - so lower-casing there makes the store agree with the two readers that were already lower-casing, and `grep -nE 'c\.data\[' config/config.go` shows the whole store is that one write, one read in get and one existence check in HasOption. Changing the readers instead would have been the larger change and would have broken Set, which has lower-cased its key since before this run.

The battery's two checks are a pair on purpose and both were needed: one reads the key back exactly as the file spells it, the other reads it lower-cased. A fix that changed the lookup would satisfy one and break the other.

Contract preserved: no signature changed. A caller whose names were already lower-case sees the same package, which the test pins explicitly with a lower-case section beside the mixed-case one. AddConfig is exported and now lower-cases what it is handed; the entry it used to store under a mixed-case name was unreachable through every reader this package has, so no caller can have been depending on it.

Learnings: none beyond what the Lessons already carry.

Next: the map is clear - twenty-six rows swept of twenty-six, none unswept. Three Mediums remain and three iterations with them: CAS-13, then CAS-24, then CAS-5. The ledger therefore reaches the severity floor only at the final iteration, which leaves no iteration for the closing full audit a declaration requires, and the closing extension cannot supply one. This run ends out of budget with the floor reached; convergence falls to the next run, which can ratchet straight to a fresh audit and the gate.

## iter 8/10 | 10a2e20f-193132 | 2026-08-31 | CAS-13 | done

Task: CAS-13 (Medium, runtime, correctness) - a filtered update whose filter matched nothing added its replacement rules and reported no change, so a policy change was made and reported as a no-op. Closed class-complete across three sites, and a second class the ledger had recorded as settled was found stale in the same enumeration and closed with it.

Changed: internal_api.go, enforcer_distributed.go and enforcer_context.go (each returns before writing when nothing matched the filter, and the context site gained the model fallback its two siblings already had), management_api_test.go (one test, eight subtests), .jeffy/probes/enforcer-context (the filtered update added to the differential table at both outcomes of its filter, claims and README updated), BACKLOG.md (CAS-13 deleted, one Settled class corrected and one added), PLAN.md (four rows re-recorded, one Lesson), JOURNAL.md.

Checkpoint: ec29061

Verification: the enumeration ran first and against the pre-fix tree 6 of its 8 subtests fail - all 5 nothing-matches cases insert [zoe data9 read] and report false, and the ContextEnforcer matching case leaves [alice data1 read] stored with the grant still in force while reporting no change. All 8 pass after the fix. Battery ownership: the diff touches internal_api.go, enforcer_distributed.go and enforcer_context.go; the paths files matching them name management-api, internal-api, enforcer-distributed and enforcer-context, which report 110/110, 230/230, 56/56 and 73/73, and all four rows are recorded at this checkpoint. check-claims.sh reports 26 checked, 0 mismatched, 0 errored, 0 skipped. Verify gate green through quiet-verify.sh (23s).

The ledger line said both sites answered identically and that the fix would cover them. Driving every public entry point that offers a filtered update found five, not two, and found a second defect at the third of them: ContextEnforcer.UpdateFilteredPoliciesCtx never read the rules to replace from the model, so against every adapter this module ships - all of which decline the updatable call - it inserted where its siblings replaced, leaving the rule the caller asked to revoke in force and reporting no change. That is the CAS-9 shape exactly, on a site the Settled classes entry claimed the class complete without.

That entry has been corrected rather than left standing, and the correction is the point: its own recorded grep listed the third site, so the enumeration was never the grep - it was the two sites someone had looked at. The line now names all three and records an executed enumeration in place of the grep, with the grep kept because it is what exposed the claim. The two defects are entangled at that site: returning early on an empty oldRules without the fallback would have made UpdateFilteredPoliciesCtx a no-op against every shipped adapter, so the fallback had to land with it rather than in a later iteration.

The enforcer-context battery is why this survived a sweep. Its row was swept on a battery whose stated shape is every *Ctx method compared against its context-free sibling, and its table did not list UpdateFilteredPoliciesCtx - the one method that had diverged. The pair is now in the table, and only half of it reddens against the pre-fix tree: with a matching filter the two forms disagree and the differential catches it, while with a filter matching nothing both forms inserted the same wrong rule and agreed with each other. The written-answer test is what grades that half, which is the standing lesson about differentials agreeing on a wrong answer, met in the wild.

Contract preserved: no signature changed. A filtered update whose filter matches keeps behaving as it did at the two sites that were already correct, which the matching half of the enumeration pins at each of them. What changes is that a filter matching nothing now writes nothing, which is how UpdatePolicy and UpdatePolicies have always answered an absent target, and that the context form replaces rather than inserts.

Learnings: a differential table certifies only the methods it lists - when a sweep says every method was compared against its sibling, count the entries against the surface before believing it.

Next: two Mediums remain and two iterations with them, CAS-24 then CAS-5, so the ledger reaches the severity floor exactly at the final iteration and no iteration is left for the closing full audit a declaration requires. This run ends out of budget with the map clear and the floor reached; convergence falls to the next run.

## iter 9/10 | 10a2e20f-193132 | 2026-08-31 | CAS-24 | done

Task: CAS-24 (Medium, docs, documentation) - EnableAutoBuildRoleLinks documented itself as controlling the rebuild "when a role is added or deleted", which is the one thing it does not control. Closed by correcting the comment to the four places that consult the flag, with an executing check behind the corrected sentence.

Changed: enforcer.go (the doc comment), enforcer_test.go (one test, four subtests), BACKLOG.md (CAS-24 deleted), PLAN.md (three rows re-recorded), JOURNAL.md.

Checkpoint: c3a67ed

Verification: `grep -rn 'autoBuildRoleLinks' --include='*.go' . | grep -v _test | grep -v '/probes/'` lists the four sites that consult the flag - the model swap in applyModifiedModel, the load from the adapter, the context load, and the transaction commit - and no site on the grouping-edit path. The new test passes and pins both halves at both values of the flag: with it off a policy-free enforcer loads rbac_policy.csv and answers false for the inherited decision until BuildRoleLinks, with it on the same load answers true, and an individual grouping add and removal take effect at once whichever way the flag is set. Battery ownership: the diff touches enforcer.go; the paths files matching it name enforcer-lifecycle, enforcer-enforce and enforcer-rolemanager, which report 108/108, 43/43 and 60/60, and all three rows are recorded at this checkpoint. The acceptance named enforcer-lifecycle's autolinks checks continuing to hold, and they do. Verify gate green through quiet-verify.sh (23s).

A documentation fix cannot fail against the tree it was written for, so the discriminating evidence is the other fix. Making the edit paths consult the flag - a three-line guard in buildIncrementalRoleLinksForRules - reddens exactly the edit-takes-effect-when-off subtest on both of its assertions and leaves the other three subtests green. That is what shows the test grades the corrected sentence rather than restating the code.

Both fixes were available and the comment is the one that was taken. Making the edit paths honour the flag would give the operator in the finding's Consequence what they asked for, but it would also silently stop grants propagating for every existing caller who turned the flag off for the load-time behaviour and kept using the edit API - a behaviour change on a v3 library, in the direction of quietly not applying a change. Correcting the comment costs those callers nothing and tells the operator in the Consequence what the flag will and will not do for them, which is what they needed to know before choosing it.

The sibling flags were checked rather than assumed. EnableAutoSave, EnableAutoNotifyWatcher and EnableAutoNotifyDispatcher are each driven at both values against an observable difference by the internal-api battery, EnableEnforce by enforcer-enforce, EnableGFunctionCache and the cache toggles by enforcer-cached, and enforcer-lifecycle drives every Enable toggle on its own surface; all are green, so EnableAutoBuildRoleLinks was the only one of the family whose sentence the code contradicted. No wider documentation class was enumerated, because "every comment matches the code" is an audit rather than a task.

Learnings: none beyond what the Lessons already carry.

Next: one Medium remains, CAS-5, and one iteration with it. The ledger reaches the severity floor at that final iteration, which leaves no iteration for the closing full audit a declaration requires and the closing extension cannot supply one, so this run ends out of budget with the map clear and the floor reached. The three carried Lows are CAS-28, CAS-22 and CAS-21.

## iter 10/10 | 10a2e20f-193132 | 2026-08-31 | CAS-5 | done

Task: CAS-5 (Medium, build-ci, documentation) - .gitattributes export-ignored .github and CONTRIBUTING.md but not the loop's own state files, so a user who downloaded the Apache source release got the agent loop's plan, ledger, journal and probe batteries inside it. Closed class-complete. This is the final iteration and CAS-5 finishes inside it, so it was worked rather than deferred to a WRAPUP; the ledger was not at the severity floor before it, which is what the final-iteration exception requires.

Changed: .gitattributes (five export-ignore lines), BACKLOG.md (CAS-5 deleted, the class recorded under Settled classes with its enumeration), JOURNAL.md.

Checkpoint: 5550822

Verification: the filed reproduction ran first - `git archive --format=tar HEAD | tar -t` listed .jeffy/ and its whole probe tree, and after the fix reports no PLAN.md, BACKLOG.md, JOURNAL.md, JOURNAL-archive.md or .jeffy/ path. The zip form was driven too, because release.yml builds both, and it is clean as well. The guard on the fix is that the archive still carries what a source release must: the tar reports LICENSE, NOTICE, README.md, go.mod and 116 Go sources, so the export-ignore lines did not take the product with them. The artifact channels were enumerated by command rather than by recall - no packaging manifest exists in the tree, and grepping .github/ for archive and upload steps names release.yml, which uses git archive, and performance-pr.yml, which uploads only a comparison.md it generates, so git archive is the one channel that reaches a published artifact. No battery declares .gitattributes, so no row is affected. check-claims.sh reports 26 checked, 0 mismatched, 0 errored, 0 skipped. Verify gate green through quiet-verify.sh (19s).

Contract preserved: nothing a user of the library can call changed. The files remain in the repository, where they are the loop's memory and are meant to be; they simply stop travelling into the source archive.

The run ends here, out of budget rather than converged, and the arithmetic is worth stating plainly because it was visible from iteration 6 and did not change. The ledger reached the severity floor only at this final iteration, so no iteration was left for the closing full audit that a declaration requires, and the closing extension cannot supply one - it buys the evaluator gate, gate-filed fixes and the declaration, and the audit a declaration cites has to predate the window. No evaluator gate was invoked this run and none could legally close it.

What the next run inherits is the cheap half of convergence: the map is clear at twenty-six rows of twenty-six, the ledger holds no High and no Medium, and every class this run closed carries an executed enumeration rather than a grep. A fresh session can spend its first iteration on the full audit and its second on the gate.

Learnings: none beyond what the Lessons already carry.

Next: three carried Lows remain - CAS-28, the transaction registry methods no caller can reach; CAS-22, the domain manager silently ignoring every domain after the first; CAS-21, a non-200 AI response with an unparseable body reported as a parse failure rather than as its status. None blocks a declaration. The next run should open with the closing full audit, then the evaluator gate.

## iter 11/12 | 10a2e20f-193132 | 2026-08-31 | WRAPUP | done

Task: the closing extension opened with the convergence sequence unstartable, so this iteration records the handoff rather than beginning work it cannot finish. No task was executed and no product file changed.

Changed: JOURNAL.md only.

Checkpoint: 88d7738

Verification: the closing position was read rather than assumed. BACKLOG.md holds three open items and all three are Low - CAS-28, CAS-22 and CAS-21 - so the ledger is at the severity floor. PLAN.md lists twenty-six swept rows and no unswept row. This run's journal headings carry no AUDIT entry, and .jeffy/evaluator/ does not exist, so no evaluator gate was invoked and no invocation ordinal is on record. The Verify gate was green at the previous checkpoint and no file has changed since; this iteration changed no product file, no BACKLOG.md item and no Surface inventory row, which is a stall by the letter of the check, and a WRAPUP is one of the ceremony entries the stall rule exempts. The previous primary entry closed CAS-5 rather than recording the same, so no pair forms.

Why the declaration is not available here, stated once and precisely. Convergence requires a full fresh-evidence audit scoring zero High and zero Medium, and the closing extension never admits one: the audit a declaration cites has to predate the window. This run has no such audit, because the ledger only reached the severity floor at iteration 10 - every one of the ten budgeted iterations went to a sweep or a fix that had to land before an audit could come back clean. The arithmetic was visible from iteration 6 and was recorded in each entry since. Declaring here would require either an audit the window forbids or a claim with nothing behind it, and the second is the failure the whole gate exists to prevent.

What the next run inherits is the expensive half of convergence already paid for. The map is complete at twenty-six rows of twenty-six, every row recorded against a battery whose paths file the closing gate can re-derive staleness from. The ledger holds no High and no Medium. Nine classes are settled, each with an executed enumeration rather than a grep, and one of those enumerations was written this run precisely because the grep it replaced had listed a site the old line claimed complete without. A fresh session can spend its first iteration on the closing full audit and its second on the gate, which is the shape the budget owes them.

Learnings: a run that starts with a mapped-but-unswept surface and a ledger of Mediums spends its whole budget earning the preconditions for a declaration and has none left to make one; the sweep-and-fix work and the convergence sequence want separate runs, not the two ends of one.

Next: nothing is queued for this run. The next run opens with a full fresh-evidence audit, then the evaluator gate, then the declaration if the audit comes back clean. The three carried Lows ride to that declaration and are not the remaining work: CAS-28, the transaction registry methods no caller outside the package can reach; CAS-22, DomainManager.getDomain silently ignoring every domain after the first; CAS-21, a non-200 AI response with an unparseable body reported as a parse failure rather than as the status it carried.

## iter 12/12 | 10a2e20f-193132 | 2026-08-31 | WRAPUP | done

Task: the last iteration of the closing extension, with nothing legal left that would move the run forward. No task was executed and no product file changed.

Changed: JOURNAL.md and PLAN.md only.

Checkpoint: cc21ff8

Verification: the closing state was re-read rather than carried over. The working tree is clean, the Verify gate is green through quiet-verify.sh (20s), and check-claims.sh reports 26 checked, 0 mismatched, 0 errored, 0 skipped. BACKLOG.md holds three open items, all Low; PLAN.md lists twenty-six swept rows and none unswept; .jeffy/evaluator/ does not exist and this run's headings carry no AUDIT entry. This iteration changed no product file, no BACKLOG.md item and no Surface inventory row, which is a stall by the letter of the check; a WRAPUP is one of the ceremony entries the rule exempts, and this is the second consecutive such entry against a bound of three.

The engine's own guidance and its governing rule disagree at this exact position, and the disagreement is worth recording because it belongs to the loop rather than to this run. The run state line asks this final iteration to be spent on the closing full audit "so the extension can then buy the gate and the declaration". There is no extension left to buy anything with: this is iteration 12 of 12 and the window was already granted at 11. The closing extension rule is stated twice and enforced mechanically - the window buys only the gate, gate-filed fixes and the declaration, never an audit, and the run ends out of budget the moment an AUDIT entry appears inside it whatever that entry claims. So an audit written here would end the run, could not be cited by any declaration, and would be superseded by the fresh audit the next run owes anyway. The guidance line reads as one written for the pre-window final iteration, where i equals N and the extension has not yet opened, firing on a condition that is also true here.

Writing it anyway would have produced a scored artifact that certifies nothing, at the end of a run whose whole discipline was that a claim carries an executed check behind it. It was not written.

Learnings: none for future iterations; the item above is a note about the engine, not a rule this project should follow.

Next: nothing is queued. The next run opens with a full fresh-evidence audit, then the evaluator gate, then the declaration if the audit comes back clean. Carried Lows are CAS-28, CAS-22 and CAS-21.

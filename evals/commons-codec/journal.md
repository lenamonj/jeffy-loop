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

## iter 1/10 | 5c26e383-225509 | 2026-09-05 | AUDIT | audit

Task: First audit of a fresh Jeffy project. Fill the Operating envelope, the Surface inventory, and the Verify command block in PLAN.md; enumerate the artifact-producing channels; probe the whole public surface breadth-first; file findings.

Changed: PLAN.md (envelope surfaces, 27 inventory rows, Verify command block, Stated counts table, two Lessons), BACKLOG.md (CODEC-1 in Now, CODEC-2 and CODEC-3 in Later), .gitignore (loop state file), JOURNAL.md.

Checkpoint: 85bb508001888b72e690730c3b103bd19fe5d3b5

Verification:
- Verify command established as `mvn -B -Drat.skip=true test`. Through the installed quiet-verify.sh: `verify: green (38s, oracle=JUnit 5 unit and parameterized tests..., [INFO] Tests run: 18925, Failures: 0, Errors: 0, Skipped: 25)`, exit 0. Verify count recorded as 18925 from that wrapper line.
- check-claims.sh: `claims: 2 checked, 0 mismatched, 0 errored, 0 skipped`, exit 0.
- Artifact channels enumerated by command, not recall. `ls src/assembly` returns bin.xml and src.xml; `sed -n '/<fileSets>/,/<\/fileSets>/p'` over both shows src.xml admitting only an explicit root include list (BUILDING.txt, CODE_OF_CONDUCT.md, CONTRIBUTING.md, LICENSE.txt, NOTICE.txt, pom.xml, README.md, RELEASE-NOTES.txt, SECURITY.md) plus the src directory, and bin.xml admitting only LICENSE.txt, NOTICE.txt, RELEASE-NOTES.txt, target/*.jar and target/site/apidocs. maven-jar-plugin packages target/classes. The four .github/workflows files archive nothing. No channel can reach PLAN.md, BACKLOG.md, JOURNAL.md, JOURNAL-archive.md or .jeffy/.
- Inventory row coverage checked mechanically: the union of the 27 rows' scope commands returns 215 paths, equal to `find src/main/java -name '*.java'` plus `find src/main/resources -type f` sorted, with no path in two rows.
- CODEC-1 reproduced against real Git. A directory holding the two names U+FF21 and U+1F600, each containing "x": `git write-tree` returns 9f9c1fc3580195f51d3e71b384ef1d57740e2151 and orders the fullwidth-A entry first (UTF-8 EF BC A1 before F0 9F 98 80); GitIdentifiers.treeId with SHA-1 returns c64581e4e48a17a50c79afc4294009fe7158eaec. Isolated as ordering, not content: single-entry directories holding each name alone agree exactly with git (865b34e9ab7a3187deee22dc3470ff22d97f7221 and 457d09c61eba846cd916a9f7a12db5452ded0402 from both implementations).
- Breadth-first probes compiled against target/classes and executed: 46 known-answer checks over Base16/32/58/64, Hex, BinaryCodec, MD5/SHA-1/SHA-256/SHA-512/SHA3-256, HMAC-SHA-256, CRC-32, CRC-32C, CRC-16/ARC, XXHash32, MurmurHash2/3, Blake3, and every phonetic and net codec, all matching published vectors; 35 edge-case probes over strict and lenient decoding, malformed escapes, empty and null input, crypt salts; 800 randomized stream round trips over the four Base-N input and output stream pairs and 1000 randomized Base58 array round trips, all exact.
- Testing dimension not scored from whole-suite runs alone: Base58Test (66 tests) and GitIdentifiersTest (23 tests) were each run in isolation and both passed.
- Scores, claiming only this breadth-first probe and explicitly not the deep sweeps still owed: correctness High (CODEC-1), code quality Low (CODEC-2), error handling Low (CODEC-3), architecture None, security None, testing None, performance None, documentation None, dependency hygiene None (all three declared dependencies are test-scope; the artifact has no runtime dependency), developer experience None. Observability does not apply: the library has no logging, metrics or tracing surface. UX and accessibility apply only to the cli.Digest entry point, which was probed and scored None. All 27 inventory rows remain unswept: this audit probed them shallowly and no row carries an executed known-answer battery yet, so these scores are the shallow pass and not the map.

Learnings: apache-rat's rat-check goal is bound to this project's default lifecycle, so a plain `mvn test` exits 1 on PLAN.md, BACKLOG.md and JOURNAL.md as the only unapproved-license files in the tree; the Verify command therefore carries -Drat.skip=true and the exclusion is recorded in the Environment fingerprint. Probing this library is cheapest by compiling a driver against target/classes rather than adding files under src/test/java, which keeps the tree clean between checkpoints.

Next: CODEC-1, the only open High.

## iter 2/10 | 5c26e383-225509 | 2026-09-05 | CODEC-1 | done

Task: CODEC-1 (High, runtime, correctness) - GitIdentifiers ordered tree entries by String.compareTo, which is UTF-16 code-unit order, where Git orders them by raw UTF-8 bytes.

Changed: src/main/java/org/apache/commons/codec/digest/GitIdentifiers.java (DirectoryEntry.sortKey becomes the UTF-8 bytes of the name, compareTo compares them unsigned, and the DirectoryEntry and sortKey Javadoc now state that the comparison is on UTF-8 bytes and why), src/test/java/org/apache/commons/codec/digest/GitIdentifiersTest.java (new testTreeIdSortsSupplementaryPlaneNamesLikeGit plus the java.io.IOException import it needs), BACKLOG.md, PLAN.md (Verify count), JOURNAL.md.

Checkpoint: 297483aba421c27b12a4da53ca2feacb2098ccba

Verification:
- Reproduction re-run first, as a backlog line is a hypothesis that rots: the standalone driver over the pre-fix classes printed codec treeId c64581e4e48a17a50c79afc4294009fe7158eaec against git's 9f9c1fc3580195f51d3e71b384ef1d57740e2151.
- Acceptance check written before the fix and observed failing on unfixed code: `mvn -B -Drat.skip=true -Dtest='GitIdentifiersTest#testTreeIdSortsSupplementaryPlaneNamesLikeGit' test` exited 1 with `expected: <9f9c1fc3580195f51d3e71b384ef1d57740e2151> but was: <c64581e4e48a17a50c79afc4294009fe7158eaec>`. After the fix the same command exits 0, Tests run: 1, Failures: 0, Errors: 0, Skipped: 0. The test asserts both paths into the sort - the virtual TreeIdBuilder with entries added in the wrong order, and treeId over a real temp directory - so neither path can regress alone.
- Differential evidence that the change moved only what it had to: the two single-entry directories that already agreed with git still return exactly their previous ids, 865b34e9ab7a3187deee22dc3470ff22d97f7221 for the U+FF21 name alone and 457d09c61eba846cd916a9f7a12db5452ded0402 for the U+1F600 name alone.
- Contract preserved: unsigned UTF-8 byte order and String.compareTo agree on every name whose characters are all below U+D800, which is every name the existing tests use, so testDirectoryEntrySortOrder and the pre-computed tree constants in testTreeIdBuilder and the filesystem test are unchanged and still pass. The order changes only where the old one disagreed with Git. compareTo is written as an explicit unsigned loop rather than Arrays.compareUnsigned because this project compiles at source and target 1.8 and that method arrived in Java 9.
- Verify gate through the installed quiet-verify.sh: `verify: green (37s, oracle=JUnit 5 unit and parameterized tests..., [INFO] Tests run: 18926, Failures: 0, Errors: 0, Skipped: 25)`, exit 0. PLAN.md Verify count moved from 18925 to 18926 to stay equal to that wrapper total.
- No battery under .jeffy/probes declares a path this diff touched; none exists yet.

Learnings: this project compiles at source and target 1.8, so Java 9+ library methods - Arrays.compareUnsigned, List.of, String.repeat - are unavailable in src/main and src/test alike.

Next: the queue's top is now the 27 unswept Surface inventory rows, which outrank the two open Lows.

## iter 3/10 | 5c26e383-225509 | 2026-09-05 | SWEEP | done

Task: Sweep unswept Surface inventory rows, the top of the queue with no open High left. Build the reusable battery machinery and sweep the six rows it could properly evidence this iteration.

Changed: .jeffy/probes/_lib (Chk.java check harness, run-battery.sh, mutate.sh), .jeffy/probes/{binary-base64,binary-base32,binary-base16,binary-base58,binary-hex-binarycodec,binary-stringutils} (Battery.java, paths, claims, README.md each), PLAN.md (six inventory rows flipped to swept), JOURNAL.md.

Checkpoint: cad6df4aaff96e88f12b4dcbd00fd1b06b4af56f

Verification:
- Six rows swept with executed known-answer batteries, never liveness probes: binary-base64, binary-base32, binary-base16, binary-base58, binary-hex-binarycodec, binary-stringutils. Twenty-one rows remain unswept.
- Answers come from outside the code under test in every case. RFC 4648 section 10 supplies the Base16, Base32 and Base64 vectors in both directions and for both Base32 alphabets. Base58 has no RFC corpus, so its vectors come from an independent Python reference implementation recorded verbatim in that battery's README. The hex answers were cross-checked against `xxd -p` and the Base32 and Base64 chunking against GNU coreutils `base64 -w 76` and `base64 -w 0`; the chunked expectations are derived inside each battery by applying the documented rounding rule to the unchunked answer rather than pasted, so a wrong chunk width fails.
- Every documented parameter of the swept surfaces was exercised at two or more values that must change the output, boundary and negative sides included: urlSafe, useHex, lowerCase, toLowerCase, lineLength (including values below the block size and negative values, which must disable chunking), lineSeparator, the Base32 pad byte, CodecPolicy at both values, the Base58 builder encode table, Hex's dataOffset, dataLen, outOffset and Charset, and StringUtils' charsetName. No parameter was found inert.
- Each battery was observed failing before it was trusted, by compiling one deliberately mutated source into a shadow classpath ahead of target/classes: base64 37/40 under a swapped standard-alphabet entry, base32 46/48 under a swapped alphabet entry, base16 18/30 under a flipped default case, base58 20/31 under BigInteger.valueOf(57), hex 26/33 under swapped digit tables, stringutils 27/30 under UTF_16BE replaced by UTF_16LE. Both the clean and the reddened counts are pinned as claims lines and re-derived by the commands recorded there. The mutation never touches the working tree: `git status --porcelain` over each mutated source was empty after every run.
- check-claims.sh over the whole tree: `claims: 14 checked, 0 mismatched, 0 errored, 0 skipped`, exit 0.
- Verify gate through the installed quiet-verify.sh: `verify: green (37s, oracle=JUnit 5 unit and parameterized tests..., [INFO] Tests run: 18926, Failures: 0, Errors: 0, Skipped: 25)`, exit 0. This iteration changed no file under src, so the suite total is unchanged from the previous checkpoint.
- Stop hook lint over the tree reports one line only, that the Converged section names no commit, which is the line every pre-declaration tree carries. Nothing was said about the battery, claims or inventory-row forms this iteration introduced.
- The sweep surfaced no finding. Two expectations of mine were wrong rather than the code: Base32 rounds lineLength down to the nearest multiple of 8, which its Javadoc states, so 76 chunks at 72; and Base16 decodes only its own alphabet case, which its class Javadoc states as strictly following RFC 4648 unlike Base32 and Base64. Both batteries now pin the documented behavior, and the second records the contrast with the case-insensitive Hex.decodeHex.

Learnings: a battery is written against the surface's own documentation before its observed output, because two of these six batteries first failed on my expectation rather than on the code, and pasting the observed value would have frozen the mistake into the instrument. Batteries live in the default package, so package-private code such as CharSequenceUtils is reached through its public caller and the README names that caller.

Next: the remaining 21 unswept rows, still the top of the queue.

## iter 4/10 | 5c26e383-225509 | 2026-09-05 | SWEEP | done

Task: Continue sweeping unswept Surface inventory rows, still the top of the queue with no open High. Swept the five digest rows this iteration.

Changed: .jeffy/probes/{digest-digestutils,digest-hmac,digest-checksums,digest-blake3,digest-murmur} (Battery.java, paths, claims, README.md each), PLAN.md (five rows flipped to swept, Environment fingerprint extended with the JVM-side algorithm exclusion, two rows added to the Stated counts table), BACKLOG.md (CODEC-4 filed), JOURNAL.md.

Checkpoint: 6b921b9093545f137af06d6b0e1f8828808e2795

Verification:
- Five rows swept: digest-digestutils, digest-hmac, digest-checksums, digest-blake3, digest-murmur. Eleven of twenty-seven rows are now swept; sixteen remain.
- Every answer comes from outside the code under test. Digests from GNU coreutils and `openssl dgst -sha3-256`; HMACs re-derived on this host with `openssl dgst -<alg> -mac HMAC -macopt hexkey:0b0b...` against RFC 2202 and RFC 4231 test case 1; CRC-32, CRC-32C and all eight shipped CRC-16 variants against their published catalogue check values for `123456789`; BLAKE3 from the official reference implementation through its Python binding, installed into a throwaway virtual environment because this host carries no b3sum and openssl offers only BLAKE2; MurmurHash2 and MurmurHash3 from independent Python implementations of the published algorithms, recorded verbatim in the digest-murmur README.
- A digest battery of per-algorithm vectors alone can be satisfied by code that ignores its algorithm argument, so differential checks sit beside every vector: the algorithm changes the digest, the key changes the mac, the mac differs from the plain digest of the same message, the two CRC-32 polynomials differ, and the three BLAKE3 modes are mutually distinct. PureJavaCrc32 is checked against java.util.zip.CRC32 over 200 random inputs, which is the contract its name claims.
- Every documented parameter was exercised at two or more values that must change the output, boundary and negative sides included: algorithm name and its unknown-name rejection, HMAC key and message, Crc16 table, init and xorOut moved independently, XXHash32 seed with 0 asserted equal to the no-argument constructor, MurmurHash seed, offset and length moved independently, Blake3 output length, key and derivation context with both rejected key-length neighbours. No parameter was found inert.
- Each battery was observed failing before it was trusted: digestutils 21/27 under SHA_256 replaced by SHA_512, hmac 15/17 under the JCE name HmacSHA256 replaced by HmacSHA384, checksums 23/26 under XXHash32 PRIME5 off by one, blake3 10/17 under an IV word off by one, murmur 19/26 under the constant 0xcc9e2d51 off by one. Clean and reddened counts are both pinned as claims lines.
- check-claims.sh over the whole tree: `claims: 26 checked, 0 mismatched, 0 errored, 0 skipped`, exit 0.
- Verify gate through the installed quiet-verify.sh: `verify: green (44s, oracle=JUnit 5 unit and parameterized tests..., [INFO] Tests run: 18926, Failures: 0, Errors: 0, Skipped: 25)`, exit 0. This iteration changed no file under src, so the total is unchanged.
- One finding filed. CODEC-4: two Javadoc sentences in MurmurHash2 say the substring overloads convert the string using the default encoding, while the code block in the same Javadoc and the implementation use UTF-8 since 1.14. The complete set of present-tense sites was enumerated by command, `grep -n 'The string is converted to bytes using the default encoding' src/main/java/org/apache/commons/codec/digest/MurmurHash2.java`, which returns the two substring overloads; the four other occurrences of "default encoding" in the digest package are historical "Before 1.14" sentences and are correct. Filed Low where the rubric suggests Medium for a documented promise the code does not keep, with this rationale: the severity ceiling by class requires a docs finding above Low to name a consequence a user of the shipped product meets, and this one cannot, because the behavior is deterministic UTF-8 on every platform and no output changes; the same Javadoc carries a code block two lines below the stale sentence that states the UTF-8 equivalence correctly, so the promise a user acts on is present and right.
- Two of my expectations were wrong rather than the code, and both are now pinned as the documented contract: MessageDigestAlgorithms names SHAKE128-256 and SHAKE256-512, whose Javadoc says "Included starting in Oracle Java 25" and which this OpenJDK 21 host does not supply; and MurmurHash2.hash32(String) hashes the UTF-8 bytes, not the UTF-16 ones. The first is now recorded in PLAN.md's Environment fingerprint with two runnable derivations, both added to the Stated counts table.

Learnings: an independent reference can be obtained for an algorithm the host has no tool for by installing the reference implementation's binding into a throwaway virtual environment, which is what made the BLAKE3 row evidenced rather than circular; pip on this host refuses to install into the system Python under PEP 668, so `python3 -m venv` is the route. A deprecated method documented as carrying a bug is pinned on both halves of that documentation, agreeing with the reference where the bug does not bite and diverging where it does, or the battery freezes the bug without recording it.

Next: the remaining 16 unswept rows.

## iter 5/10 | 5c26e383-225509 | 2026-09-05 | SWEEP | done

Task: Continue sweeping unswept Surface inventory rows. Swept digest-crypt, net-url-percent and net-quotedprintable, and filed the two High findings those sweeps surfaced.

Changed: .jeffy/probes/{digest-crypt,net-url-percent,net-quotedprintable} (Battery.java, paths, claims, README.md each), PLAN.md (three rows flipped to swept), BACKLOG.md (CODEC-5 and CODEC-6 filed in Now), JOURNAL.md.

Checkpoint: 880f15da50d720cd83455ceaa8a54fce71755912

Verification:
- Three rows swept: digest-crypt, net-url-percent, net-quotedprintable. Fourteen of twenty-seven rows are now swept; thirteen remain.
- Answers from outside the code under test: every crypt hash re-derived here with `openssl passwd -1 -salt saltstri`, `-5 -salt saltstring`, `-6 -salt saltstring` and `perl -e 'print crypt("secret","ab")'`; the URL answers against `urllib.parse.quote_plus`; the quoted-printable answers against `quopri.encodestring`.
- Each battery was observed failing: crypt 21/23 under ROUNDS_DEFAULT off by one, url-percent 16/26 under ESCAPE_CHAR changed from '%' to '!', quotedprintable 19/20 under SAFE_LENGTH 73 changed to 40. The quoted-printable battery did not detect that last mutation at first, because a shorter safe line length is still valid quoted-printable and every existing check still passed; a check pinning where the first soft break lands was added for exactly that reason, and the mutation reddens it. An instrument that cannot see a constant change is not measuring that constant.
- check-claims.sh over the whole tree: `claims: 32 checked, 0 mismatched, 0 errored, 0 skipped`, exit 0.
- Verify gate through the installed quiet-verify.sh: `verify: green (44s, oracle=JUnit 5 unit and parameterized tests..., [INFO] Tests run: 18926, Failures: 0, Errors: 0, Skipped: 25)`, exit 0. No file under src changed this iteration.
- CODEC-5 filed (High, runtime, correctness). Sha2Crypt.sha256Crypt, Sha2Crypt.sha512Crypt and Md5Crypt.md5Crypt zero the caller's key byte array in place. Found because the battery's first draft shared one key array across checks and every check after the first hashed zeros. Reproduced as the ordinary hash-then-verify pattern: h = Sha2Crypt.sha512Crypt(password, "$6$saltstring") followed by Crypt.crypt(password, h) returns a different string from h, and that second value was confirmed equal to the hash of a 13-byte zero array; the password array reads all zeros afterwards. The clearing sits beside a comment about clearing intermediate buffers so core dumps leak nothing, but keyBytes and saltBytes are the caller's arrays, not intermediates, and no Javadoc on any of the three public methods mentions it. UnixCrypt.crypt(byte[], String) was checked too and does not mutate its input. No test in the project pins the behavior.
- CODEC-6 filed (High, runtime, correctness). QuotedPrintableCodec in strict mode returns null for any input shorter than the private MIN_BYTES = 3, so encode("") , encode("a") and encode("ab") are all null while encode("abc") works, against a Javadoc that promises a quoted-printable string and documents null only for a null input. Found by a randomized round trip whose failing case reduced to the empty string. The behavior is pinned in the battery rather than skipped, so the fix will redden it and have to update it.
- Two of my expectations were wrong rather than the code. The Sha2Crypt salt pattern ends in ".*" on purpose, which is what lets a stored hash be handed back as the salt, so trailing text after the salt is taken as salt rather than rejected; that is now pinned as the contract. And URLCodec's safe set is not urllib's: it leaves '*' unescaped and escapes '~', both now pinned explicitly.

Learnings: a battery that shares one input array across checks will find any function that mutates its input, which is how CODEC-5 surfaced; the array must then be made per-call so the battery measures the algorithm rather than the defect. A mutation that a battery does not detect is a gap in the battery, not a failed mutation: pin the constant directly rather than only its consequences.

Next: CODEC-5 and CODEC-6 are open Highs and outrank the thirteen remaining unswept rows.

## iter 6/10 | 5c26e383-225509 | 2026-09-05 | CODEC-5 | done

Task: CODEC-5. Filed last iteration as a High claiming Sha2Crypt and Md5Crypt zero the caller's key array undocumented; corrected this iteration to the narrower finding that survives evidence, and fixed that.

Changed: src/main/java/org/apache/commons/codec/digest/Crypt.java (both byte[] overloads now document the clearing, per branch), src/test/java/org/apache/commons/codec/digest/CryptTest.java (new testCryptClearsKeyBytesOnlyOnTheAlgorithmsThatDocumentIt plus the two imports it needs), .jeffy/probes/digest-crypt (Battery.java comment and README corrected), BACKLOG.md, PLAN.md (Verify count), JOURNAL.md.

Checkpoint: 872fc14b8b220775822c6476dc8ceac3efa3ba97

Verification:
- The reproduction was re-run first and still reproduces: through Crypt, hash-then-verify returns a different string from the stored hash and the caller's array reads all zeros afterwards.
- The premise was then wrong and is corrected here rather than acted on. Sha2Crypt documents the clearing on 7 of its 7 keyBytes parameters and Md5Crypt on 10 of its 10, each reading "Each array element is set to {@code 0} before returning". Last iteration's grep looked for zero, cleared, wiped and destroy and matched none of them, so the finding was filed as undocumented behavior when the behavior is designed and documented. Counts derived by `grep -c '@param keyBytes.*set to {@code 0}'` against each file. CODEC-5 is therefore rescored from High, runtime to Medium, docs and rewritten to the part that holds: Crypt, the dispatcher a caller is most likely to use, documents none of it - `grep -c` over Crypt.java returned 0.
- The claim now written into Crypt.java generalises over its dispatch, so the set was enumerated by provoking every branch rather than by reading the source: null salt, $6$, $5$ and $1$ each leave the array all zeros, and the DES fallback leaves it holding its original bytes. Those are all five branches of crypt(byte[], String).
- Acceptance, both halves. The discriminating half is the grep: `grep -c '@param keyBytes.*set to {@code 0}' src/main/java/org/apache/commons/codec/digest/Crypt.java` returned 0 before the edit and returns 2 after. The second half is the new JUnit test, which drives all five branches and asserts the array is zeroed on four and untouched on the DES one; it passes on the pre-fix code too, by design, because its job is to keep the new sentence true rather than to detect its absence. `mvn -B -Drat.skip=true -Dtest='CryptTest#testCryptClearsKeyBytesOnlyOnTheAlgorithmsThatDocumentIt' test` exits 0, Tests run: 1, Failures: 0.
- Contract preserved: no runtime behavior changed. The diff outside the test is Javadoc only, so every caller of Crypt, Sha2Crypt, Md5Crypt and UnixCrypt sees exactly what it saw before.
- Battery ownership: the diff touches src/main/java/org/apache/commons/codec/digest/Crypt.java, which .jeffy/probes/digest-crypt declares. That battery was re-run through check-claims.sh: `claims: 6 checked, 0 mismatched, 0 errored, 0 skipped`, exit 0, both its clean and reddened counts still matching.
- Verify gate through the installed quiet-verify.sh: `verify: green (38s, oracle=JUnit 5 unit and parameterized tests..., [INFO] Tests run: 18927, Failures: 0, Errors: 0, Skipped: 25)`, exit 0. PLAN.md Verify count moved 18926 to 18927 for the new test.
- Closed this iteration: CODEC-5 (Medium, docs) - Crypt's two byte[] overloads now carry the per-branch clearing contract their delegates document, pinned by a test over all five dispatch branches.

Learnings: search a Javadoc for the behavior's own wording before calling it undocumented; the phrase here was "set to {@code 0}", which a grep for zero, cleared or wiped does not match, and a High was filed on that gap. Confirm a finding's premise against the documentation of the exact methods named, not against a keyword sweep of the file.

Next: CODEC-6, the remaining open High.

## iter 7/10 | 5c26e383-225509 | 2026-09-05 | CODEC-6 | blocked

Task: CODEC-6, filed as a High claiming QuotedPrintableCodec strict mode returns null below three bytes against a Javadoc that promises a string. The fix broke the project's own test suite and was reverted; the finding is rescored and split.

Changed: BACKLOG.md (CODEC-6 marked [b] with its reason, CODEC-7 filed in Next, one Proposed item added), JOURNAL.md. Nothing under src or .jeffy/probes: this iteration's edits there were reverted.

Checkpoint: 7bf87411dad662fcd80d58b1d2b3dd291e347d9e

Verification:
- Reproduction re-run first and still holds: strict mode returns null at lengths 0, 1 and 2 and works from 3 up.
- A fix was written and its acceptance check was observed failing first and passing after. The short path encodes the octets directly, applying rule #3 to the final one; `mvn -B -Drat.skip=true -Dtest='QuotedPrintableCodecTest#testStrictEncodeShortInput' test` exited 1 with `expected: <> but was: <null>` before the change and exited 0 after, and the seven expected forms were taken from `quopri.encodestring(s, quotetabs=True)`.
- The Verify gate then failed where it had been green at the previous checkpoint: `QuotedPrintableCodecTest.testTooShortByteArray:223 Result should be null. ==> expected: <null> but was: <AA>`, Tests run: 18928, Failures: 1. Per the verify-gate rule the working tree was reverted to the last jeffy checkpoint with `git checkout -- src .jeffy/probes`, and the gate is green again on the reverted tree: `verify: green (50s, oracle=JUnit 5 unit and parameterized tests..., [INFO] Tests run: 18927, Failures: 0, Errors: 0, Skipped: 25)`, exit 0.
- The newly-red-test exception was considered and does not apply. It covers a test that was green only because of the defect being fixed. Here `git log -S` shows MIN_BYTES and testTooShortByteArray both entering in commit c65de5c6, "CODEC-313: Fix possible ArrayIndexOutOfBoundsException thrown by QuotedPrintableCodec.encodeQuotedPrintable()", so the null is a deliberate maintainer decision with a test written to assert it, not a fault my change exposed. Encoding short input reverses that decision, which is not this loop's call to make.
- CODEC-6 is therefore marked [b] with that reason, and what survives is split in two. CODEC-7 (Medium, docs) is the part that is uncontroversially wrong and fixable: the public encode methods document their return as a quoted-printable string and document null only for a null input, while strict mode also returns null below three bytes; a caller of a one or two byte body gets null with no warning. The behavior question - should it encode instead - is a Proposed item, because changing a published return value that an upstream issue chose deliberately needs the maintainer.
- I searched for a test pinning this before writing the fix and missed it: the grep output was truncated by `head -30` and testTooShortByteArray sits below the cut. The verify gate is what caught it, which is what the gate is for, but the search should have found it first.
- Battery ownership: the reverted diff leaves .jeffy/probes untouched, so no battery's declared paths changed. check-claims.sh was run before the revert and reported `claims: 32 checked, 0 mismatched, 0 errored, 0 skipped`; the tree is now identical to the checkpoint that count was taken against.

Learnings: before changing any public behavior, search the test tree for a test that asserts it and read `git log -S` on the constant or guard involved; a behavior with a named test and a JIRA id in its commit message is a decision, not a defect, and the remedy is a Proposed item plus a documentation fix. Never truncate a grep for pinning tests with head; the line that matters is as likely to be the twelfth as the second.

Next: CODEC-7, the documentation half, which is now the top open item above the thirteen unswept rows only if it is worked as a Medium - the map outranks it, so the sweep is next unless the budget says otherwise.

## iter 8/10 | 5c26e383-225509 | 2026-09-05 | SWEEP | done

Task: Sweep unswept Surface inventory rows, the top of the queue with no open High. Swept language-soundex and language-metaphone, and filed the finding the second sweep surfaced.

Changed: .jeffy/probes/{language-soundex,language-metaphone} (Battery.java, paths, claims, README.md each), PLAN.md (two rows flipped to swept), BACKLOG.md (CODEC-8 filed in Later), JOURNAL.md.

Checkpoint: 967c3161bc641ef3facfbfab21ee74293cdd721e

Verification:
- Two rows swept: language-soundex and language-metaphone. Sixteen of twenty-seven rows are now swept; eleven remain.
- Answers from outside the code under test: eighteen names encoded by the jellyfish Python library, installed into a throwaway virtual environment, for both Soundex and Metaphone. Every one of the thirty-six was compared name by name against this implementation before being pinned, and all agreed - Soundex directly, Metaphone against setMaxCodeLen(20) because jellyfish returns the untruncated code. Nysiis and the match rating codex were checked the same way and agreed too; those belong to a row still unswept.
- Refined Soundex has no reference here that agrees on the variant, since abydos implements a different one, so the battery computes its answers from the documented US_ENGLISH_MAPPING_STRING letter by letter, independently of the class. That independent computation agrees with the implementation on all six names checked.
- Both batteries were observed failing: soundex 40/42 under the last character of the Soundex mapping changed, metaphone 36/38 under maxCodeLen defaulting to 5 instead of 4.
- check-claims.sh over the whole tree: `claims: 36 checked, 0 mismatched, 0 errored, 0 skipped`, exit 0.
- Verify gate through the installed quiet-verify.sh: `verify: green (48s, oracle=JUnit 5 unit and parameterized tests..., [INFO] Tests run: 18927, Failures: 0, Errors: 0, Skipped: 25)`, exit 0. No file under src changed this iteration.
- Three of my expectations were wrong rather than the code, and each is now pinned as the real contract. The mapping I passed as a "custom" Soundex mapping was the default one, so the check proved nothing until a genuinely different mapping replaced it, and the default's own value is now pinned separately so that mistake cannot recur silently. Refined Soundex collides Robert with Rupert exactly as Soundex does, because o and u both map to 0 and b and p both map to 1 under the documented table; what distinguishes it is that its codes are not truncated. And DoubleMetaphone's alternate encoding of Smith is the sh-initial branch XMT rather than the primary.
- CODEC-8 filed (Medium, docs). DoubleMetaphone.encode(String) documents its return as "An encoded String" and returns null for empty input where Metaphone.encode("") returns the empty string. I checked for a pinning test before treating it as a defect this time, and DoubleMetaphoneTest asserts the null, so the behavior is intended and only the documentation is missing. Its acceptance grep was made discriminating after the first draft returned 1 rather than 0 on today's tree.
- CODEC-8 is the second finding sharing one root cause with CODEC-7, an undocumented null return from a method whose Javadoc promises a String. A third instance would end instance work under the three-strike rule and become one structural task or one Proposed decision; that is noted here so the next audit inherits the count rather than rediscovering it.

Learnings: when a battery exercises a parameter by passing a "custom" value, pin the default's own value beside it, or a custom value that is secretly the default will pass as evidence that the parameter works. Check the encoder's own test class for a pinning assertion before filing any null return as a defect; two of the three null returns found in this run turned out to be tested, intended behavior.

Next: eleven unswept rows remain, and the run has two iterations left, so the map cannot clear this run; the remaining budget goes to sweeping and then a handoff.

## iter 1/10 | 8c07b4bf-000140 | 2026-09-05 | SWEEP | done

Task: Sweep unswept Surface inventory rows, the top of the queue with no open High - CODEC-6 is blocked. Swept six rows and filed the two findings the sweeps surfaced.

Changed: .jeffy/probes/{digest-gitidentifiers,cli-digest,net-rfc1522,binary-basencodec,codec-core-api,codec-core-support} (Battery.java, paths, claims, README.md each), BACKLOG.md (CODEC-9 and CODEC-10 filed in Later, the section reordered by severity then class), JOURNAL.md. Nothing under src.

Checkpoint: 830fe2d97dc32648c3e9c6edd14630fc816d311c

Verification:
- Six rows swept: digest-gitidentifiers, cli-digest, net-rfc1522, binary-basencodec, codec-core-api and codec-core-support. Twenty-two of twenty-seven rows are now swept; five remain, all of them phonetic - language-caverphone-nysiis-mra, language-cologne-dm, language-bm-engine, language-bm-rules and language-bm-resources.
- Answers from outside the code under test, one oracle per row. git itself for GitIdentifiers: git hash-object -t blob for the blob ids, a second repository created with git init --object-format=sha256 for the generalized one, and git write-tree plus git rev-parse <tree>:<dir> for every tree id, which is the right oracle because the class documents its output as "identical to those used by Git". GNU coreutils md5sum, sha1sum, sha256sum and sha512sum for the command line. RFC 2047 section 8's published encoded words, plus Python's base64 and quopri, for the RFC 1522 codecs. The real encoded output for BaseNCodec's getEncodedLength promise. The JDK's own StandardCharsets and Charset.forName for the two charset mirrors, the shipped dmrules.txt compared byte for byte against the source tree for Resources, and Soundex codes already pinned against jellyfish for the comparator.
- Every battery was observed failing, two discriminating mutations each, and both counts are pinned in the battery's claims file: gitidentifiers 35/36 under a signed name-byte comparison and 34/36 with the directory slash dropped; cli-digest 24/28 with one space before a file name and 16/28 with a byte appended to the string branch; rfc1522 61/64 with the underscore rule dropped and 54/64 with lower case hex escapes; basencodec 59/64 with the chunk-separator term dropped from getEncodedLength and 61/64 with allowWhitespacePad ignored; core-api 37/41 with the format constructor not formatting and 40/41 with a changed serial id; core-support 35/36 with toCharset not defaulting on null and 35/36 with the comparator not swallowing an encoder failure.
- check-claims.sh over the whole tree: `claims: 54 checked, 0 mismatched, 0 errored, 0 skipped`, exit 0.
- Verify gate through the installed quiet-verify.sh: `verify: green (52s, oracle=JUnit 5 unit and parameterized tests..., [INFO] Tests run: 18927, Failures: 0, Errors: 0, Skipped: 25)`, exit 0. No file under src changed this iteration, so the count is unmoved.
- CODEC-10 filed (Low, docs). The DirectoryEntry Javadoc illustrates Git's tree-sort rule with "so that foo/ sorts after foobar", and that is the one ordering the rule cannot produce: '/' is 0x2f and 'b' is 0x62, so foo/ sorts first. Real git confirms it - a tree holding a directory foo beside the files foo-x, foo.txt and foobar lists them foo-x, foo.txt, foo, foobar - and the correct example is foo.txt, whose '.' is 0x2e. The code is right and only the sentence is wrong; DirectoryEntry is package-private, so no published Javadoc carries it, which is why this is a Low rather than a Medium.
- CODEC-9 filed (Low, runtime). Base64InputStream.builder().get() builds without an input stream and throws NullPointerException on the first read, naming neither setInputStream nor setByteArray; setByteArray(null) reaches the same state. The binary-basencodec battery pins today's behavior with the ledger id on the check, so the iteration that fixes it has to update the battery in the same commit.
- CODEC-9 is the second finding sharing a root cause with CODEC-3, a builder whose get() yields an object that fails later with an unhelpful NullPointerException naming neither the missing setting nor the method that supplies it. A third instance ends instance work under the three-strike rule and becomes one structural task or one Proposed decision; recording the count here so the next audit inherits it.
- Six of my expectations were wrong rather than the code's, and every one of them was a value I had derived by hand or assumed: Base32 accepts "abc" because it decodes case-insensitively, Base64 refuses a line separator containing a base64 character, the reversed-alphabet encoding of abc is bdqQ and not byqM, AbstractBuilder has no toString of its own, Hex declares only the binary pair and is no kind of StringEncoder, and Soundex and Metaphone agree on the order of the four names I first chose. Each is now pinned as the real contract, with a discriminating pair (Knight and Lee) replacing the four names that proved nothing.
- Two mutations had to be discarded because they crashed the battery instead of reddening it - making getChunkSeparator return the shared array breaks Base64's own constructor, and renaming CodecPolicy.STRICT stops the battery compiling - so neither could print the summary line a claim compares against.

Learnings: take reference values from the real tool wherever one exists rather than deriving them by hand; git hash-object, git write-tree and coreutils were right every time this iteration and three of my hand-derived expectations were wrong. And choose a mutation whose blast radius stops at the checks: a mutation that breaks a static initializer or the battery's own compilation kills the summary line the claim is compared against, so it cannot be pinned at all.

Next: five unswept rows remain, all phonetic. The Beider-Morse rows need an outside reference for a large rule-driven encoder, so the next sweep starts with language-caverphone-nysiis-mra and language-cologne-dm, where jellyfish and abydos give one.

## iter 2/10 | 8c07b4bf-000140 | 2026-09-05 | SWEEP | done

Task: Sweep unswept Surface inventory rows, still the top of the queue with no open High. Swept language-caverphone-nysiis-mra and language-cologne-dm, and filed the Medium the second sweep surfaced.

Changed: .jeffy/probes/{language-caverphone-nysiis-mra,language-cologne-dm} (Battery.java, paths, claims, README.md each), BACKLOG.md (CODEC-11 filed in Next), JOURNAL.md. Nothing under src.

Checkpoint: 8cc3f330809931319c64be949c66c7d03eb1aeb5

Verification:
- Two rows swept: language-caverphone-nysiis-mra and language-cologne-dm. Twenty-four of twenty-seven rows are now swept; three remain, all Beider-Morse.
- Answers from outside the code under test. abydos supplied Caverphone at both versions, the truncated NYSIIS, MRA, Koelner and Daitch-Mokotoff; jellyfish supplied the untruncated NYSIIS and independently confirmed every MRA codex. Both vector tables were generated by printing the reference libraries' output as Java source rather than transcribed, per the lesson from the previous iteration.
- NYSIIS's strict parameter has a separate reference on each side: strict truncates to six, which is abydos's output, and strict(false) does not, which is jellyfish's. Both tables are pinned, the two settings are checked to really disagree on Washington, and the strict code is checked to be a prefix of the unabridged one at every name.
- Daitch-Mokotoff matches abydos on all twelve published JewishGen example pairs, compared as sorted branch sets so output order does not matter. Its folding parameter is exercised at both values on the sharp s, where it changes the code from 294000 to 290000.
- Both batteries were observed failing: caverphone 147/158 with the NYSIIS truncation shortened to five and 130/158 with Caverphone 2 padded to eight; cologne-dm 90/102 with the CODEC-317 guard dropped and 82/102 with the Daitch-Mokotoff length shortened to five.
- check-claims.sh over the whole tree: `claims: 60 checked, 0 mismatched, 0 errored, 0 skipped`, exit 0.
- Verify gate through the installed quiet-verify.sh: `verify: green (40s, oracle=JUnit 5 unit and parameterized tests..., [INFO] Tests run: 18927, Failures: 0, Errors: 0, Skipped: 25)`, exit 0. No file under src changed this iteration, so the count is unmoved.
- CODEC-11 filed (Medium, docs). ColognePhonetic disagrees with abydos on exactly one class of input, a vowel between two identical consonant codes: Honeyman 06 against 0666, Aumont 062 against 0662, hoffmann 036 against 0366, moenchengladbach 64645214 against 664645214, Eberhard 0172 against 01772, Celsius 858 against 8588. Five of those six are values the project's own ColognePhoneticTest pins.
- I checked for a pinning test and the history before treating that as a defect, per the standing lesson, and the history is decisive: commit 2cdfac1a, "[CODEC-317] ColognePhonetic can create duplicate consecutive codes in some cases", introduced the guard `if (nonZ && accept)` that suppresses the second digit and rewrote hoffmann, moenchengladbach, Eberhard, Eberhardt and Celsius in the test file in the same commit, from exactly the abydos values to the current ones. So the behavior is a maintainer decision and not this loop's to reverse, and no Proposed item is filed to re-litigate a decision the project made deliberately.
- What CODEC-317 did not do is update the class Javadoc. Step 3 still reads "This means that two or more identical consecutive digits can occur if they occur after removing the '0' digits", which is the behavior the code no longer has, so the finding is the documentation gap and is scored Medium as a documented promise the code does not keep, with the Consequence a caller meets stated on the line.
- The guard is the whole of the difference, and that is measured rather than argued: reverting `if (nonZ && accept)` to `if (accept)` turns this implementation into abydos on all six names and reddens exactly the twelve checks that pin them, 90 of 102, leaving the other ninety untouched.
- The Javadoc's two worked examples still hold under the current code - Mueller-Luedenscheidt gives 65752682 and Wikipedia 3412 - which is why the divergence survived: the examples do not discriminate, only the sentence does. Both are pinned in the battery so the CODEC-11 fix cannot break them.
- The battery pins both sides of all six divergent names, the implementation's answer as a known answer and a differs check against abydos's, so whichever changes is visible.
- Two of my expectations were wrong again and both were about which input discriminates a parameter: Mueller does not distinguish Daitch-Mokotoff folding on from off, and neither does an e-grave, because the cleanup already handles them; only the sharp s does. And the deprecated Caverphone class is an alias for version 2, not version 1, which the battery now pins on both sides.

Learnings: when a reference implementation and this project disagree, run git log -S on the guard before scoring anything - here it produced a JIRA id, a commit that rewrote the test's expected values in the same change, and a title stating the old behavior was the bug, which turned a suspected correctness defect into a documentation one. And measure that a suspected cause is the whole cause by reverting it: flipping the single CODEC-317 guard reproduced the reference's answers on all six names and nothing else moved.

Next: three unswept rows remain, all Beider-Morse - language-bm-engine, language-bm-rules and language-bm-resources. abydos ships a BeiderMorse encoder, so an outside reference exists; the resources row is 127 rule files and needs a structural sweep rather than a per-name one.

## iter 3/10 | 8c07b4bf-000140 | 2026-09-05 | SWEEP | done

Task: Sweep the three remaining Surface inventory rows, all Beider-Morse. The map is now complete.

Changed: .jeffy/probes/{language-bm-engine,language-bm-rules,language-bm-resources} (Battery.java, paths, claims, README.md each), JOURNAL.md. Nothing under src, and nothing in BACKLOG.md: these sweeps surfaced no in-envelope finding.

Checkpoint: 36e426580f52af661385eee847e60fd39fc80eee

Verification:
- Three rows swept: language-bm-engine, language-bm-rules and language-bm-resources. Twenty-seven of twenty-seven rows are now swept and the Surface inventory lists no unswept row.
- language-bm-engine, 111 checks. The reference is abydos's BeiderMorse over twelve names in the six modes both implementations support, the three name types crossed with the two match modes, compared as sorted phoneme sets with maxPhonemes raised to 4000 so the default limit of twenty does not truncate a set abydos returns whole. 71 of the 72 combinations agree exactly.
- The independence of that reference is limited and the README says so rather than implying more: abydos's Beider-Morse and this one both descend from the same upstream BMPM rule tables, so what the comparison establishes is that two separately written engines, each with its own copy of the rules, walk them to the same answer. That is worth having and it is not an independent oracle in the sense git hash-object is for GitIdentifiers.
- The one disagreement is Mueller under generic-approximate: this implementation returns seven phonemes and abydos eleven, the extra four being mQlir, mvYlir, mvili and mvilir. The same name under ashkenazi-approximate agrees on both sides including the mQlir that generic omits. Deciding which is right means comparing the two projects' rule-file vintages for the German approximate rules, which this sweep did not do, so no finding is filed - the evidence rule does not admit a speculative one - and the battery pins this implementation's current answer as a labelled regression guard with the abydos answer recorded beside it. It is carried into the run report as an open question for a later run.
- language-bm-rules, 62 checks. No phonetic answers of its own, so the reference is the shipped tables: for each name type the battery reads <type>_languages.txt directly, without going through the classes under test, and requires the list the class reports to be exactly the list the file declares. The LanguageSet algebra is exercised on all three implementations, Lang's guesses are pinned on names that narrow (szczepanski to polish) and on the invariant that every language Lang can guess is one the matching Languages instance declares.
- language-bm-resources, 19 checks. There is no outside reference for a hundred-odd hand-maintained rule files, so the check is closure in both directions: every table the code can name loads and parses to at least one rule, and every file that ships is one the code can reach. The second half is what nothing else checks - a file that ships and nothing loads is dead weight that reads as coverage.
- My first reachability model was wrong and the battery caught it: it reported the three <type>_exact_approx_common.txt files as orphans, and they are not, because rule tables pull in others with #include and those three are reached only that way. Following the include graph transitively fixed it and made the check stronger, since the graph is now checked for closure too: every #include must name a file that ships, and all three shared tables must be included by something.
- All three batteries were observed failing: bm-engine 108/111 with the default phoneme limit lowered to twelve and 62/111 with the phoneme separator changed; bm-rules 58/62 with restrictTo keeping every language instead of intersecting and 61/62 with a stray character appended in Phoneme.append; bm-resources 16/19 with one language dropped from the shipped language list, where the orphan check names the six now-unreachable tables, and 13/19 with Rule no longer recognizing its own #include directive.
- check-claims.sh over the whole tree: `claims: 69 checked, 0 mismatched, 0 errored, 0 skipped`, exit 0.
- Verify gate through the installed quiet-verify.sh: `verify: green (54s, oracle=JUnit 5 unit and parameterized tests..., [INFO] Tests run: 18927, Failures: 0, Errors: 0, Skipped: 25)`, exit 0. No file under src changed this iteration, so the count is unmoved.
- Five expectations of mine were wrong again and all five were about what a parameter does rather than about a wrong answer. concat looked inert because I tested it on "van Peters", where a recognized name prefix is handled before the words are split; six of eight other inputs discriminate it, so it is not a finding and the prefix case is now pinned as its own contract. maxInputLength is a limit that refuses an over-long input, not a truncation. RuleType.RULES names the raw rule set and the engine refuses to be built with it. A negative maxPhonemes is documented as resetting to the default rather than failing. And NameType's declaration order is alphabetical, not GENERIC first.
- One mutation was discarded as inert for a reason worth recording: Languages.ANY and Rule.ALL are static final String constants, so javac inlines them into the battery at compile time and changing them in the source reddens nothing at all.

Learnings: before filing a documented parameter as inert, enumerate inputs until one discriminates it - concat read as dead on the first input tried and works on six of the next seven, and the input that failed to discriminate did so for a documented reason of its own. And a static final String constant cannot be mutation-tested through a battery that references it by name, because javac inlines the value at the battery's own compile time; mutate the code that consumes the constant instead.

Next: the map is complete, so the queue drops to the open Medium tasks - CODEC-7, then CODEC-11 and CODEC-8. No full fresh-evidence audit has run this run, so the closing sequence still needs one before any declaration.

## iter 4/10 | 8c07b4bf-000140 | 2026-09-05 | CODEC-7 | done

Task: CODEC-7, the top open Medium now that the map is complete. QuotedPrintableCodec's encode methods documented their return as a quoted-printable string and documented null only for a null input, while strict mode also returns null for any input shorter than MIN_BYTES = 3.

Changed: src/main/java/org/apache/commons/codec/net/QuotedPrintableCodec.java (Javadoc only, six methods), .jeffy/probes/net-quotedprintable (three checks added, claims re-measured, README updated), BACKLOG.md, JOURNAL.md.

Checkpoint: d9f8e0ce19b6208798ce8a689eff062e41c14c8f

Verification:
- The filed reproduction was re-run as this iteration's first command and still reproduces: with a strict codec, encode returns null at lengths 0, 1 and 2 and works from 3 up, while a lenient codec encodes all five.
- The sentence added generalises over a set of sites, so the set was enumerated by provoking the null return at every public entry point rather than by grepping the source. Six return null on a two-byte body under a strict codec: encode(byte[]), encode(String), encode(String, Charset), encode(String, String), encode(Object), and the three-argument static encodeQuotedPrintable(BitSet, byte[], boolean). The two-argument static overload is the lenient one and encodes the same body normally, so it is outside the set - a fact the provocation found and a grep for calls would not have.
- All six now carry the sentence and no other method does: `grep -c 'shorter than three bytes'` over the file returns the same six, and reading the method signature under each match shows exactly the six enumerated above. My first draft used two phrasings, "shorter than" for the byte-array methods and "fewer than" for the String ones, which would have left a single grep enumerating half the set; the wording was unified so one command drives every site the claim covers.
- Acceptance, all three parts. The discriminating grep returned 0 before the edit and 6 after. The sentence appears on every public encode overload reached by the strict path, enumerated above. And testTooShortByteArray still passes: `mvn -B -Drat.skip=true -Dtest='QuotedPrintableCodecTest#testTooShortByteArray' test` exits 0.
- Contract preserved: the diff outside the battery is Javadoc only. No signature, no behavior and no accepted input changed, so every caller of QuotedPrintableCodec sees exactly what it saw before, and the Surface inventory row is re-recorded rather than flipped back to unswept.
- Battery ownership: the diff touches src/main/java/org/apache/commons/codec/net/QuotedPrintableCodec.java, which only .jeffy/probes/net-quotedprintable declares. It passed unchanged at 20/20, as a Javadoc-only change should, and was then extended so the executable check covers the same set as the prose claim: one check drives all six strict entry points, one pins the lenient two-argument static on the other side, and one pins the three-byte boundary on all six. It now stands at 23/23.
- A second mutation was added to that battery and it is the one that matters here: lowering MIN_BYTES from 3 to 2 reddens 2 of the 23 checks by raising ArrayIndexOutOfBoundsException, which is the exception CODEC-313 introduced the guard to prevent and is the reason the new Javadoc gives for the null. The claim in the documentation is therefore executable rather than asserted.
- check-claims.sh over the whole tree after re-measuring: `claims: 70 checked, 0 mismatched, 0 errored, 0 skipped`, exit 0.
- Verify gate through the installed quiet-verify.sh: `verify: green (42s, oracle=JUnit 5 unit and parameterized tests..., [INFO] Tests run: 18927, Failures: 0, Errors: 0, Skipped: 25)`, exit 0. The count is unmoved because no test was added to src/test.
- Closed this iteration: CODEC-7 (Medium, docs) - the strict below-three-bytes null return is now documented on all six public entry points that produce it, with the reason, and the battery drives every one of them.
- CODEC-6 remains blocked and unchanged: this task documented the behavior rather than altering it, which is what the Proposed item exists to decide.

Learnings: when a documentation fix states a rule that covers several methods, write one form of words for all of them - two near-synonyms split the enumeration in half and the acceptance grep silently certified only the sites that happened to match. And after documenting a behavior, pin it with a mutation that reproduces the failure the behavior exists to prevent; that turns the sentence into something the battery can falsify rather than something only a reader can check.

Next: CODEC-11 and CODEC-8, the two remaining Mediums, both documentation. After those the ledger is at the severity floor and the run still owes a full fresh-evidence audit before any declaration.

## iter 5/10 | 8c07b4bf-000140 | 2026-09-05 | CODEC-11 | done

Task: CODEC-11, the top open Medium. The ColognePhonetic class Javadoc's Step 3 described an algorithm the code deliberately stopped implementing under CODEC-317, and the sentence was left standing.

Changed: src/main/java/org/apache/commons/codec/language/ColognePhonetic.java (Javadoc only, the Step 3 paragraph), .jeffy/probes/language-cologne-dm (README and one Battery.java comment brought current), BACKLOG.md, JOURNAL.md.

Checkpoint: ce2a7e0af795b013194c177a2efe7121c658dbdf

Verification:
- The filed reproduction was re-run as this iteration's first command and still reproduced on both halves: the sentence "two or more identical consecutive digits can occur if they occur after removing the '0' digits" was present, and none of the six names it describes behaves that way - hoffmann gives 036 where the documented step order gives 0366, Eberhard 0172 against 01772, Celsius 858 against 8588, Honeyman 06 against 0666, Aumont 062 against 0662, moenchengladbach 64645214 against 664645214.
- Step 3 now states what the code does: a removed "0" does not separate the digits around it, so where the same digit stands on either side of a removed "0" the pair collapses to one, with hoffmann as the worked example, and it names CODEC-317 as the change that introduced the collapsing.
- I wrote and then withdrew a stronger sentence. The first draft said "the rule as Postel states it keeps the pair, and other implementations of the Koelner Phonetik still do". Neither half was evidenced: I have not read Postel 1969, and "other implementations" generalises over a set I enumerated at exactly one member. The shipped sentence is narrowed to what is checkable - that applying step 2 and step 3 strictly in that order leaves the pair standing, which is a derivation anyone can redo, that this is what the documentation said before CODEC-317, which git shows, and that an implementation following that order returns 0366, which is measured.
- Acceptance, all four parts. `grep -n 'identical consecutive digits can occur'` over ColognePhonetic.java returned one line before the edit and no line after. Step 3 states the collapsing and cites CODEC-317, quoted above. Both worked examples still hold: Mueller-Luedenscheidt gives 65752682 and Wikipedia gives 3412, unchanged. And the language-cologne-dm battery still matches all three of its recorded claims, 102/102 clean, 90/102 and 82/102 under its two pinned mutations.
- Contract preserved: the diff outside the battery is a Javadoc paragraph. No signature, no behavior and no accepted input changed, so the Surface inventory row for language-cologne-dm is re-recorded at this checkpoint rather than flipped back to unswept.
- Battery ownership: the diff touches src/main/java/org/apache/commons/codec/language/ColognePhonetic.java, which only .jeffy/probes/language-cologne-dm declares. It was re-run and passes at 102/102. Its README and one Battery.java comment described CODEC-11 as an open gap and now record it as closed; the six divergent names stay pinned on both sides, so the day the behavior itself changes the battery reddens.
- check-claims.sh over the whole tree: `claims: 70 checked, 0 mismatched, 0 errored, 0 skipped`, exit 0.
- Verify gate through the installed quiet-verify.sh: `verify: green (40s, oracle=JUnit 5 unit and parameterized tests..., [INFO] Tests run: 18927, Failures: 0, Errors: 0, Skipped: 25)`, exit 0. The count is unmoved because no test was added.
- Closed this iteration: CODEC-11 (Medium, docs) - Step 3 of the ColognePhonetic algorithm description now matches the code, names the change that made them differ, and keeps both of its worked examples.

Learnings: a documentation fix is a prose claim like any other, so it is held to the evidence rule - a sentence about what a standard says or what other implementations do needs the standard read or the implementations enumerated, and where neither was done the sentence is narrowed to the derivation and the one measurement that back it.

Next: CODEC-8, the last open Medium, also documentation. After it the ledger is at the severity floor with five Lows, and the run still owes a full fresh-evidence audit before the evaluator gate and any declaration.

## iter 6/10 | 8c07b4bf-000140 | 2026-09-05 | CODEC-8 | done

Task: CODEC-8, the last open Medium. DoubleMetaphone's encode and doubleMetaphone methods documented their return as "An encoded String" and never mentioned the null they return for empty input, where Metaphone returns the empty string.

Changed: src/main/java/org/apache/commons/codec/language/DoubleMetaphone.java (Javadoc only, four methods), .jeffy/probes/language-metaphone (six checks added, a second mutation pinned, claims re-measured, README updated), BACKLOG.md, JOURNAL.md.

Checkpoint: 3e6ea682d09a7901ae8e091579eaffc796773c22

Verification:
- The filed reproduction was re-run as this iteration's first command and still reproduces: DoubleMetaphone.encode("") is null where Metaphone.encode("") is the empty string.
- The enumeration corrected the filing on both counts, which is why the reproduction is run first. The backlog line named two methods; provoking the null at every public entry point found four - encode(String), encode(Object), doubleMetaphone(String) and doubleMetaphone(String, boolean). And the condition is not "empty input": cleanInput trims before testing, so encode("   ") is null too, while encode("123") and encode("!!") survive it and return the empty string. The documented sentence says "empty or whitespace-only" because that is what the guard does.
- Acceptance, restated where it was wrong and run where it was right. Its discriminating half holds: the Javadoc of every method that produces the null now states it, checked before and after by `grep -c 'for an empty or whitespace-only input'` against `git show HEAD:` and the working tree, which returned 0 and then 4, and reading the signature under each of the four matches shows exactly the four entry points enumerated above. DoubleMetaphoneTest still passes, exit 0.
- Two parts of the acceptance as filed could not be run as written and are corrected rather than quietly dropped. It expected the literal phrase "null for an empty", which the shipped sentence does not contain because it writes {@code null}: this file uses {@code null} four times and bare null in prose zero times, and CODEC-7 set the same convention in the net package last iteration, so matching the literal string would have meant writing worse Javadoc than the code around it. And it expected a count of 2, which was the under-enumeration described above. The corrected enumerating command and its result are recorded here.
- Contract preserved: the diff outside the battery is Javadoc only. No signature, no behavior and no accepted input changed, so the Surface inventory row for language-metaphone is re-recorded at this checkpoint rather than flipped back to unswept.
- Battery ownership: the diff touches src/main/java/org/apache/commons/codec/language/DoubleMetaphone.java, which only .jeffy/probes/language-metaphone declares. It passed unchanged at 38/38 and was then extended so the executable checks cover the same set as the new sentence: all four entry points driven on both an empty and a whitespace-only input, plus the digits-and-punctuation boundary that makes "whitespace-only" the right word, plus Metaphone returning the empty string for all three. It now stands at 44/44.
- A second mutation was pinned and it is the one that matters: removing the trim() from cleanInput reddens exactly the two checks CODEC-8's sentence rests on, the whitespace-only null and the contrast with digits. The documented claim is therefore falsifiable by the battery rather than only readable.
- check-claims.sh over the whole tree after re-measuring: `claims: 71 checked, 0 mismatched, 0 errored, 0 skipped`, exit 0.
- Verify gate through the installed quiet-verify.sh: `verify: green (40s, oracle=JUnit 5 unit and parameterized tests..., [INFO] Tests run: 18927, Failures: 0, Errors: 0, Skipped: 25)`, exit 0. The count is unmoved because no test was added.
- Closed this iteration: CODEC-8 (Medium, docs) - the null return is documented on all four public entry points that produce it, with the real condition rather than the assumed one, and the battery drives every one of them.
- The ledger is now at the severity floor: no open High or Medium, five open Lows, and CODEC-6 blocked.

Learnings: an acceptance check is written before the enumeration and can be wrong in both directions at once - this one named half the sites and the wrong condition, and also demanded a literal phrasing that would have contradicted the file's own Javadoc convention. Run the reproduction, re-derive the set, then state plainly which parts of the check were run as written and which were corrected and why; a check quietly reworded to pass is worth nothing.

Next: the ledger is at the floor and the map is complete, but no full fresh-evidence audit has run this run, so the closing sequence needs that audit next, then the evaluator gate, then a declaration if the gate passes. Four iterations remain, which is enough for the audit, the gate as its own iteration, and the declaration.

## iter 7/10 | 8c07b4bf-000140 | 2026-09-05 | AUDIT | audit

Task: The closing full fresh-evidence audit. The ledger is at the severity floor and the Surface inventory lists no unswept row, so this is the audit the declaration has to cite. It files nothing.

Changed: JOURNAL.md only. Nothing under src, no BACKLOG.md item changed state, and no Surface inventory row changed state - this iteration is a no-progress iteration by the stall check's own definition, and it says so here. It is an AUDIT that files nothing, which the ceremony exemption covers, so it does not form a blocking pair with the entry before it.

Checkpoint: 19874a0be31adfb9e2e243a56150d7a256ea0e23

Verification:
- Scope: every score below claims the whole project, because the Surface inventory lists 27 of 27 rows swept and each row names a battery whose paths file declares what it covers. No dimension is scored on an unexamined remainder.
- Evidence re-executed rather than re-read. All 27 batteries and PLAN.md's Stated counts table: `claims: 71 checked, 0 mismatched, 0 errored, 0 skipped`, exit 0. The Oracle class and Environment fingerprint were re-read and their four derived counts re-run: 2 excluded performance tests, 9 files carrying conditional or disabled targets, 2 Java-25-only algorithms, JVM major version 21. Declined and Settled classes are both empty, so there is no recorded Derivation or enumeration to re-run.
- Testing, per the audit discipline that a suite only ever run whole hides order dependence: five modules were run in isolation - Base64Test, ColognePhoneticTest, DoubleMetaphoneTest, QuotedPrintableCodecTest and DigestUtilsTest - and each exits 0 on its own.
- Artifact channels re-verified by command and per channel, not by recall. The tree's channels are pom.xml, src/assembly/src.xml, src/assembly/bin.xml and four GitHub workflows. Building for real produced eight artifacts - the jar, sources, tests and test-sources jars, and the src and bin assemblies as both tar.gz and zip - and each was searched for PLAN.md, BACKLOG.md, JOURNAL.md, JOURNAL-archive.md and any .jeffy path. All eight carry zero. The search was given a positive control on the same archive, which finds README.md and pom.xml, so the zeros mean absence rather than a broken pattern. The source assembly is an allowlist of nine root files plus src/, which is why the loop's state cannot reach it.
- Security, on the surface the Operating envelope classifies adversarial. A fresh probe drove 4000 rounds of random hostile bytes through sixteen decoders and encoders - Base64, Base32, Base16, Base58, Hex, URLCodec, QuotedPrintable, BCodec, QCodec, Crypt, Soundex, DoubleMetaphone, ColognePhonetic, Caverphone2, Nysiis and Daitch-Mokotoff - under a 512 MB heap, counting only uncontained failures, meaning OutOfMemoryError or StackOverflowError rather than a declared exception. Zero uncontained failures across all sixteen.
- Performance: a Base64 round trip at 1, 2, 4 and 8 MB takes 54, 89, 81 and 133 ms, so cost per megabyte falls as the input grows and there is no quadratic behaviour in the range tested; the 8 MB round trip is byte-identical. SHA-256 over an 8 MB stream takes 60 ms.
- Documentation: `mvn javadoc:javadoc` exits 0 with zero errors and zero warnings, including the three files this run edited.
- Dependency hygiene: the project declares four dependencies and every one of them is test-scoped, so the shipped jar has no compile or runtime dependency and no third-party attack surface to inherit.
- The five carried Lows were each re-verified to still reproduce, so the ledger the declaration rests on is accurate: CODEC-9 still raises NullPointerException naming neither setter, CODEC-3 still raises NullPointerException("table"), CODEC-2's equals-on-name is still there, CODEC-4's two sentences are still present, and CODEC-10's wrong sort example is still present.
- Verify gate through the installed quiet-verify.sh: `verify: green (50s, oracle=JUnit 5 unit and parameterized tests..., [INFO] Tests run: 18927, Failures: 0, Errors: 0, Skipped: 25)`, exit 0.

Dimension scores, fresh evidence, whole project:
- correctness: None. 27 batteries and 71 claims all matching, 18927 tests green, five modules green in isolation.
- security: None. 64000 hostile-input calls across sixteen decoders, zero uncontained failures; no compile or runtime dependencies.
- error handling: None above Low. Two Lows open, CODEC-9 and CODEC-3, both builders raising an unhelpful NullPointerException on a surface the envelope classifies user-error.
- documentation: None above Low. Two Lows open, CODEC-4 and CODEC-10; the Javadoc build is clean.
- testing: None. The rubric caps this dimension at Low regardless; the suite is green whole and in isolation.
- performance: None. Linear or better to 8 MB on the Base-N path and on the digest path.
- dependency hygiene: None. Zero compile and runtime dependencies.
- architecture: None. The whole public surface is mapped in 27 rows, each naming a battery that declares its own paths.
- code quality: None above Low. One Low open, CODEC-2.
- developer experience: None above Low. The build, the Javadoc and both assemblies all run clean from a fresh invocation.
- observability: not applicable. A codec library exposes no logging, metrics or tracing surface; there is nothing in this dimension to score.
- UX and accessibility: not applicable beyond the command line, which is its own swept row, cli-digest, driven end to end through its real main method. There is no graphical or interactive surface.

Zero High and zero Medium in-envelope. Closeout has begun: the run stops auditing for the rest of the run, files no replenishment, and finishes by working or declining what is on the ledger and then converging.

Learnings: verify an absence with a positive control in the same command - the artifact check reports zero loop-state entries in eight archives, and that number only means anything because the same pattern run against the same archive finds README.md and pom.xml. A zero from a pattern that never matched anything is indistinguishable from a zero from a pattern that is broken.

Next: the evaluator gate, invocation 1 of this run, and a declaration in that same iteration if it returns PASS and the closing conditions still hold. Three iterations remain, so a REJECT can still be answered and a second invocation spent.

## iter 8/10 | 8c07b4bf-000140 | 2026-09-05 | EVALUATOR | audit

Task: The adversarial evaluator gate, invocation 1 of this run. It returned REJECT on one substantiated reason, so the run does not converge; the reason is filed and the run continues.

Changed: BACKLOG.md (CODEC-12 filed in Later at Medium, CODEC-13 at Low), PLAN.md (one dangling finding id repaired before the invocation), .jeffy/evaluator/8c07b4bf-000140-1.md (the gate's artifact), JOURNAL.md.

Checkpoint: 3bd24f0187e53432d92ddc52bdc0b918ee36c504

Verification:
- Standing claims were brought current before invoking, so no invocation would be spent on a claim this run had already outdated. No swept row is stale: every row's battery paths file was resolved to real files and `git diff <row commit> HEAD` over them is empty for all 27. Declined and Settled classes are both empty, so there is no recorded Derivation or enumeration to re-run. check-claims.sh: `claims: 71 checked, 0 mismatched, 0 errored, 0 skipped`. The Oracle class and Environment fingerprint were re-read and the Verify count cell, 18927, equals the wrapper's green total.
- One repair was needed and it would have cost the invocation: PLAN.md's language-cologne-dm row said the six divergent names were "recorded as CODEC-11", an id this run closed in iteration 5, leaving a reference that resolves to no ledger line - exactly what the gate is told to treat as a REJECT reason. The row now states that the class Javadoc's Step 3 documents the collapsing, and `grep -c 'CODEC-' PLAN.md` returns no match.
- The Stop hook in lint mode printed one line before the invocation: that the Converged section names no commit. That is the declaration's own last step and nothing else was flagged.
- Verify gate through the installed quiet-verify.sh before invoking: `verify: green (58s, oracle=JUnit 5 unit and parameterized tests..., [INFO] Tests run: 18927, Failures: 0, Errors: 0, Skipped: 25)`, exit 0. The evaluator re-ran it independently and got the same result at 59s.
- Evaluator: REJECT, invocation 1 of at most 2 for this run, since the first invocation landed at iteration 8 and the midpoint of a ten-iteration budget is five. The artifact is committed at .jeffy/evaluator/8c07b4bf-000140-1.md; it opens with the run id, the ordinal and the invoking iteration, lists 38 commands with their real exit statuses, and contains no machine-absolute path.
- The reason is real and I reproduced it independently rather than taking the verdict at face value. DoubleMetaphone.encode(Object) guards with !(obj instanceof String), and null is not an instance of String, so encode((Object) null) throws EncoderException. The sentence CODEC-8 added to that overload promises {@code null} for a {@code null} input, and adds that Metaphone returns the empty string in those cases, which is false there too because Metaphone.encode((Object) null) throws as well. The empty and whitespace-only half of the same sentence is true - encode((Object) "") and encode((Object) "   ") both return null - so the defect is one clause of four sites, not the whole fix.
- This is my defect, introduced by this run in iteration 6, and the gate is what caught it. The enumeration behind CODEC-8 provoked the null return at each entry point using a String argument, which reaches encode(Object) through its delegated-to type and never exercises the guard that overload has of its own. The battery extended in the same iteration drove encode(Object) with "" and "   " and never with null, so the clause that is false was the one clause no check executed.
- The gate found the same blind spot at a second site, which makes it a class rather than an instance: QuotedPrintableCodec.encode(Object) accepts a String as well as a byte array, so a strict codec returns null for encode((Object) "ab"), and the sentence CODEC-7 added there names only a byte array shorter than three bytes. That one is incomplete rather than false. Both are filed as a single task, CODEC-12, per the rule that the class is fixed rather than each instance, with an acceptance that re-derives each Object overload's contract by provoking it with null, a wrong type and every accepted type.
- CODEC-13 filed at Low: the reason clause CODEC-7 added, "since the full ruleset cannot place a soft line break in a body that short", is not the reason. A lenient codec encodes the same two-byte body and Python quopri returns it unchanged, so shortness does not prevent encoding; the real cause is the CODEC-313 negative-index guard, which the pinned MIN_BYTES mutation reproduces. Scored Low because the behavior statement beside it is correct, so a caller is given a wrong rationale rather than a wrong contract.
- The iteration 4 entry states that the new Javadoc gives the ArrayIndexOutOfBoundsException as the reason for the null. It does not; it gives the soft-line-break clause. Past entries are never rewritten, so the correction is recorded here.
- Everything else the gate checked held: CODEC-7 and CODEC-11 both reproduce at the base commit and pass at HEAD with their acceptance checks re-executed, check-claims has no mismatch, no PLAN.md Stated counts row drifted, the five carried Lows are accurately scored, and CODEC-6's blocked rationale was independently verified against commit c65de5c6.
- The gate also recorded one Low observation about my own reasoning: iteration 6 justified keeping {@code null} markup by appeal to "the file's own convention", and that file had zero null mentions at the base commit, so the convention cited was partly the fix's own text. The conclusion survives on the project-wide count, but the derivation as I wrote it was circular.

Learnings: a delegating overload has a guard of its own, so provoking a behavior through the type it delegates with never exercises it - the enumeration for a claim about encode(Object) has to pass null and a wrong type to that overload directly, not just the type it forwards. Both Object overloads this run documented went wrong the same way, which is what makes it one class and not two accidents.

Next: CODEC-12, the Medium the gate filed, in iteration 9, then the second and final evaluator invocation with a declaration in iteration 10 if it passes. CODEC-13 is a Low and is carried.

## iter 9/10 | 8c07b4bf-000140 | 2026-09-05 | CODEC-12 | done

Task: CODEC-12, the Medium the evaluator gate filed at iteration 8. Both encode(Object) overloads this run documented had been enumerated through the type they delegate with rather than through their own guard, so one sentence was false and the other incomplete.

Changed: src/main/java/org/apache/commons/codec/language/DoubleMetaphone.java and src/main/java/org/apache/commons/codec/net/QuotedPrintableCodec.java (Javadoc only, one @return and one @throws each), .jeffy/probes/language-metaphone (five checks added, a third mutation pinned) and .jeffy/probes/net-quotedprintable (five checks added), both claims files re-measured and both READMEs updated, BACKLOG.md, JOURNAL.md.

Checkpoint: 1072df68d46a189cf39613df5cb1ca318983815d

Verification:
- The gate's reproduction was re-run as this iteration's first command and still reproduced: DoubleMetaphone.encode((Object) null) throws EncoderException where the shipped sentence promised null.
- Each Object overload's contract was re-derived by provoking it with null, with a wrong type, and with every accepted type, which is what the acceptance asks and what iteration 6 failed to do. DoubleMetaphone.encode(Object): null throws, Integer throws, "" and "   " return null, "Smith" returns SM0. QuotedPrintableCodec.encode(Object) on a strict codec: null returns null, Integer throws, a two-byte array returns null, a two-character String returns null, and both forms encode at three. Metaphone.encode(Object) was provoked the same way for the comparison sentence: null throws, "" and "   " return the empty string.
- The two sentences now say what those runs show. DoubleMetaphone.encode(Object) states that it returns null only when the argument is a String that is empty or whitespace-only, that it accepts a String and nothing else, and that a null argument raises EncoderException rather than returning null; its @throws now names null explicitly. QuotedPrintableCodec.encode(Object) now covers a byte array or a String shorter than three bytes rather than a byte array alone.
- The correction is confined to the one overload that was wrong. The three String-taking DoubleMetaphone methods do return null for null - checked directly, encode((String) null), doubleMetaphone(null) and doubleMetaphone(null, true) are all null - so their sentences stand unchanged, and `grep -c 'null} for a {@code null} input'` returns 3, sitting on exactly those three.
- The enumerations the earlier fixes rest on are intact: `grep -c 'shorter than three bytes'` over QuotedPrintableCodec still returns 6, CODEC-7's six entry points, and `grep -c 'empty or whitespace-only'` over DoubleMetaphone still returns 4, CODEC-8's four.
- Contract preserved: both diffs are Javadoc only. No signature, no behavior and no accepted input changed, so both affected Surface inventory rows are re-recorded at this checkpoint rather than flipped back to unswept.
- Battery ownership: the diff touches DoubleMetaphone.java and QuotedPrintableCodec.java, declared by language-metaphone and net-quotedprintable respectively. Both were extended so the corrected sentences are executable: each now drives its Object overload with null and with a wrong type, which is precisely the probe whose absence let the false clause ship. language-metaphone stands at 49/49 and net-quotedprintable at 28/28.
- A third mutation is pinned on language-metaphone and it is the one that matters here: letting a null argument past encode(Object)'s type guard reddens exactly the check that pins CODEC-12's corrected clause, 48 of 49. Every previously pinned mutation was re-measured against the larger batteries rather than carried over: 47/49 and 46/49 on language-metaphone, 27/28 and 24/28 on net-quotedprintable.
- check-claims.sh over the whole tree: `claims: 72 checked, 0 mismatched, 0 errored, 0 skipped`, exit 0.
- `mvn javadoc:javadoc` exits 0 with zero errors and zero warnings.
- Verify gate through the installed quiet-verify.sh: `verify: green (72s, oracle=JUnit 5 unit and parameterized tests..., [INFO] Tests run: 18927, Failures: 0, Errors: 0, Skipped: 25)`, exit 0.
- Closed this iteration: CODEC-12 (Medium, docs) - both Object overloads now document the contract their own guards produce, and both batteries drive those guards.
- CODEC-13 is not batched into this iteration. It is a separate root cause, an inaccurate reason clause rather than a wrong contract, it is scored Low, and the rule is one task per iteration; it is carried and named in the declaration.
- The ledger is back at the severity floor: no open High or Medium, six open Lows, and CODEC-6 blocked.

Learnings: when the gate files a defect in this run's own work, the fix has to close the hole in the method that produced it, not just the text - the sentence was corrected and the same iteration added the probe whose absence let it ship, so the check that would have caught it now exists at both sites.

Next: the second and final evaluator invocation, with a declaration in that same iteration if it returns PASS. The cap is two invocations because the first landed at iteration 8, past the midpoint of a ten-iteration budget, so a second REJECT would be terminal and the run would end blocked with the declaration deferred to the next run's fresh gate.

## iter 10/10 | 8c07b4bf-000140 | 2026-09-05 | EVALUATOR | converged

Task: The second and final evaluator invocation of this run, and the declaration. The gate returned PASS and every closing condition holds, so the run converges.

Changed: .jeffy/evaluator/8c07b4bf-000140-2.md (the gate's artifact), BACKLOG.md (the Converged line, appended in this iteration's bookkeeping commit), JOURNAL.md.

Checkpoint: 5b1919109883b60ad3fbc1125b7e01ad591639fb

Verification:
- Standing claims were brought current before invoking. All 27 Surface inventory rows are swept and none is stale: each row's battery paths file was resolved to real files and `git diff <row commit> HEAD` over them is empty. check-claims.sh: `claims: 72 checked, 0 mismatched, 0 errored, 0 skipped`. PLAN.md names no finding id at all, so nothing dangles. Declined and Settled classes are both empty, so there is no recorded Derivation or enumeration to re-run. The Oracle class and Environment fingerprint were re-read and the Verify count cell, 18927, equals the wrapper's green total.
- The Stop hook in lint mode printed one line, that the Converged section names no commit, which is the declaration's own last step. Nothing else was flagged.
- Verify gate through the installed quiet-verify.sh this iteration: `verify: green (70s, oracle=JUnit 5 unit and parameterized tests..., [INFO] Tests run: 18927, Failures: 0, Errors: 0, Skipped: 25)`, exit 0. The evaluator re-ran it independently at 69s and got the same figures.
- Evaluator: PASS. Invocation 2 of at most 2 for this run, the cap being 2 because the first invocation landed at iteration 8, past the midpoint of a ten-iteration budget. The artifact is at .jeffy/evaluator/8c07b4bf-000140-2.md, opening with the run id, the ordinal and the invoking iteration, listing 62 commands with their real exit statuses and carrying no machine-absolute path.
- The gate verified that invocation 1's REJECT reason is genuinely resolved rather than papered over. It provoked DoubleMetaphone.encode(Object) with null, Integer, byte[], StringBuilder, three whitespace forms and a name, and QuotedPrintableCodec.encode(Object) with null, a wrong type and both accepted types under both policies, and found every clause now shipped on both overloads true, including the Metaphone comparison that was the false half.
- It also closed the one gap invocation 1 could only accept as a hand derivation: it extracted, compiled and ran the pre-CODEC-317 ColognePhonetic and measured hoffmann giving 0366 against HEAD's 036, which is exactly what the Step 3 sentence CODEC-11 wrote says, with both worked examples unchanged across that commit.
- The whole product diff of this run is 39 Javadoc lines across three files, and the gate proved it behaviourally inert rather than reading it: base and HEAD were compiled separately and the same probe drivers run against both, with byte-identical output.
- Closing conditions, each checked rather than asserted: the full fresh-evidence audit at iteration 7 scored zero High and zero Medium in-envelope; the Surface inventory lists no unswept row, 27 of 27; no open High and no open Medium remains in Now, Next or Later; the only commits since that audit are the evaluator gate's own iteration, the fix for CODEC-12 which the gate itself filed, and loop state edits; the Verify command is green this iteration; and the evaluator returned PASS.
- Carried Lows, each open with its severity on its task line, listed here as the closing rule requires:
  - CODEC-13 (Low, docs): the reason clause CODEC-7 added to encodeQuotedPrintable is not the real reason for the null; the contract half of the same sentence is correct at all six sites, which is why it is a Low.
  - CODEC-9 (Low, runtime): a Base64InputStream built with no input throws NullPointerException on first read, naming neither setInputStream nor setByteArray.
  - CODEC-2 (Low, runtime): GitIdentifiers.DirectoryEntry orders on sortKey but defines equals and hashCode on name alone; the class is package-private.
  - CODEC-3 (Low, runtime): Crc16.builder().get() with no table throws NullPointerException("table"), naming neither the setting nor the builder method.
  - CODEC-4 (Low, docs): two MurmurHash2 Javadoc sentences say the substring overloads use the default encoding where the code uses UTF-8.
  - CODEC-10 (Low, docs): the DirectoryEntry Javadoc illustrates Git's tree-sort rule with the one ordering the rule cannot produce; the class is package-private.
- CODEC-6 remains blocked, not open: strict-mode QuotedPrintableCodec returning null below three bytes is a maintainer decision carrying a JIRA id and a named test, so the behaviour question is the Proposed item and the documentation half was closed as CODEC-7.
- The gate recorded six Low observations and none is a REJECT reason, so per the closing rule none is fixed inside this sequence; a fix after a PASS invalidates that PASS. They go to the run report and the next run's ledger. The sharpest is that .jeffy/probes/net-quotedprintable/README.md repeats the CODEC-13 error, saying the Javadoc gives the ArrayIndexOutOfBoundsException as the reason when it gives the soft-line-break clause, so the blind spot survives in loop memory as well as in the shipped file.

Learnings: the gate earns its cost when it is given something to disprove rather than to admire - invocation 1 found a false clause this run had shipped and invocation 2 reproduced, by compiling the pre-change class, the one claim the first invocation could only take as a derivation. Two invocations of an adversary that reproduces beat any number of readings.

Next: convergence is declared at this checkpoint. The next run starts from a swept map and a ledger at the severity floor, so its first task is CODEC-13, then the remaining Lows, and its fresh audit re-scores everything from scratch.

> **Summary — generated for DocumentEngine `v0.4.0` (CMTAT `v3.3.0-rc3`, OpenZeppelin `v5.7.0`).**
>
> | | |
> | --- | --- |
> | Command | `slither . --checklist --filter-paths "node_modules,lib,test,forge-std,mocks"` |
> | Tool version | `slither 0.11.5` |
> | Scope | `src/` only — 28 contracts analysed with 101 detectors (the count includes inherited OpenZeppelin/CMTAT contracts pulled in by the compiler; findings are filtered to project sources). **Mocks/tests excluded** — this project's mocks (`CMTATDocumentEngineMock`, `OpenDocumentEngine`, `OverridingDocumentEngine`) live in `test/DocumentEngine.t.sol`, which the `test` filter removes. |
> | Result | **0 High · 0 Medium · 0 Low · 2 Informational** (2 results) |
> | Verdict | **Nothing to fix.** Both results are required Solidity overrides misread as dead code. |
>
> | Detector | Severity | Confidence | Instances | Assessment |
> | --- | --- | --- | --- | --- |
> | `dead-code` | Informational | Medium | 2 | **False positive** — `_msgData()` is a *mandatory* override; removing it fails to compile (verified) |
>
> **Changed since the previous run — read this before comparing counts.** This report has 2 results
> where the previous run had 4. The `incorrect-equality` (Medium) and `timestamp` (Low) findings on
> `_removeDocument`'s `doc.lastModified == 0` no longer fire, because the code-quality review's
> finding B-2 changed `Document memory doc` to `Document storage doc`. **Nothing was fixed by that** —
> the comparison is character-for-character the same and was a false positive to begin with (see the
> feedback file). Slither's taint tracking simply stops classifying the value as timestamp-derived
> when it is read through a storage pointer instead of a memory copy. Do not read the drop from 4 to
> 2 as a security improvement; it is a detector artefact.
>
> **Scope check:** `grep -c 'lib/\|node_modules/'` over the tool output below returns **0** — no
> dependency code is in scope. This is a Foundry project, so the dependency filter entry is `lib`;
> note this differs from the command previously documented in the README, which listed individual
> submodule names and would have left `lib/RuleEngine` unfiltered.
>
> Full triage, with the reasoning verified against each cited line:
> [`slither-report-feedback.md`](./slither-report-feedback.md).
> Companion Aderyn run: [`../aderyn/aderyn-report.md`](../aderyn/aderyn-report.md).
> Code-quality review: [`../claude/CLAUDE_ANALYSIS.md`](../claude/CLAUDE_ANALYSIS.md).
> Security overview: [`doc/audits/AUDIT_OVERVIEW.md`](../../../AUDIT_OVERVIEW.md).

**THIS CHECKLIST IS NOT COMPLETE**. Use `--show-ignored-findings` to show all the results.
Summary
 - [dead-code](#dead-code) (2 results) (Informational)
## dead-code
Impact: Informational
Confidence: Medium
 - [ ] ID-0
[DocumentEngine._msgData()](src/DocumentEngine.sol#L155-L157) is never used and should be removed

src/DocumentEngine.sol#L155-L157


 - [ ] ID-1
[DocumentEngineOwnable._msgData()](src/DocumentEngineOwnable.sol#L82-L84) is never used and should be removed

src/DocumentEngineOwnable.sol#L82-L84



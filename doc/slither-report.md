**THIS CHECKLIST IS NOT COMPLETE**. Use `--show-ignored-findings` to show all the results.
Summary
 - [dead-code](#dead-code) (1 results) (Informational)
 - [solc-version](#solc-version) (1 results) (Informational)
## dead-code

> Acknowledge

Impact: Informational
Confidence: Medium

 - [ ] ID-0
[DocumentEngine._msgData()](src/DocumentEngine.sol#L265-L272) is never used and should be removed

src/DocumentEngine.sol#L265-L272

## solc-version

> Acknowledge

Impact: Informational
Confidence: High
 - [ ] ID-1
	Version constraint ^0.8.20 contains known severe issues (https://solidity.readthedocs.io/en/latest/bugs.html)
	- VerbatimInvalidDeduplication
	- FullInlinerNonExpressionSplitArgumentEvaluationOrder
	- MissingSideEffectsOnSelectorAccess.
	 It is used by:
	- lib/CMTAT/contracts/interfaces/engine/draft-IERC1643.sol#3
	- lib/openzeppelin-contracts/contracts/access/AccessControl.sol#4
	- lib/openzeppelin-contracts/contracts/access/IAccessControl.sol#4
	- lib/openzeppelin-contracts/contracts/metatx/ERC2771Context.sol#4
	- lib/openzeppelin-contracts/contracts/utils/Context.sol#4
	- lib/openzeppelin-contracts/contracts/utils/introspection/ERC165.sol#4
	- lib/openzeppelin-contracts/contracts/utils/introspection/IERC165.sol#4
	- src/DocumentEngine.sol#2
	- src/DocumentEngineInvariant.sol#2


# Null `subject` in multi-subject document management — superseded working note

> **Superseded.** Everything this note proposed now exists as a full ERC draft:
> [`doc/ERCSpecification/erc-draft_multi_document_management.md`](./doc/ERCSpecification/erc-draft_multi_document_management.md).
> That draft is the normative document; this file is kept only as a record of how the decision was
> reached and where the outcome differs from what was first proposed. Do not cite it as a
> specification.

## Outcome

| | First proposed here | Adopted in the draft |
| --- | --- | --- |
| Error name | `ERC1643InvalidSubject()` | **`MultiDocumentInvalidSubject()`** |
| Where declared | ERC-1643's extension section | its own interface, `IERC1643MultiDocument` |
| Normative strength | `SHOULD` revert on `subject == address(0)` | `SHOULD` — unchanged |
| Guarded paths | write path only | write path only — unchanged |
| Security note | one line | a dedicated *The null subject* consideration |

The implementation follows the draft: `DocumentEngineBase._setDocument` reverts
`MultiDocumentInvalidSubject()`, declared in `src/interfaces/IERC1643MultiDocument.sol`.

## Why the name changed

The original proposal reused ERC-1643's prefix for symmetry with `ERC1643InvalidName()` and
`ERC1643MissingDocument()`. The draft rejects that, on the principle that **an error is prefixed by
the proposal that defines its condition, not by the proposal it happens to sit next to**:

- `ERC1643InvalidName` / `ERC1643MissingDocument` keep their prefix because they genuinely *are*
  ERC-1643's errors, reused unchanged so that revert data is identical whether a caller is talking to
  an ERC-1643 contract or to a multi-subject manager. Renaming them would fragment that.
- The null-`subject` condition **cannot arise in ERC-1643 at all**: its `setDocument` has no
  `subject` argument, so the subject is implicitly the contract itself, which is never the null
  address. Borrowing the `ERC1643` prefix would name the error after a standard in which the
  condition is unreachable.

The name is provisional, along with `IERC1643MultiDocument` and `IMultiDocumentSubject`; all three
track the draft's own number once an editor assigns one. The two reused ERC-1643 names are **not**
provisional.

## What still holds from the original reasoning

Retained by the draft, and still the justification for the guard:

- **Not a security hole.** Namespaces are isolated (`_documents[subject][name]`), and `address(0)`
  cannot call the contract to read "its own" documents, so a document stored under the null subject
  is inert.
- **But a data-integrity issue.** `subject` is by definition the address of the contract the
  documents belong to; `address(0)` is never such a contract. Allowing it lets callers populate a
  namespace no contract can ever own, cluttering state and misleading off-chain indexers that key on
  `subject`.
- **Guarding the write path is sufficient.** With `setDocument` rejecting the null subject, no
  document can exist under it, so `removeDocument` there already fails with
  `ERC1643MissingDocument()`. No second guard is needed.
- **Precedent.** ERC-20 / ERC-721 reject the zero address on mint and transfer for the same
  "never a meaningful participant" reason.

The same argument is what motivates rejecting `address(0)` in `bindToken` / `unbindToken`
(`src/modules/TokenBindingModule.sol`), which is not a specification requirement but follows from
the identical premise.

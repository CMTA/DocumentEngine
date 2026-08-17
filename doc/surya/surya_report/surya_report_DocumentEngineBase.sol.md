## Sūrya's Description Report

### Files Description Table


|  File Name  |  SHA-1 Hash  |
|-------------|--------------|
| ./DocumentEngineBase.sol | 30ea1b25c7af9e478f0dbb2b1e984672c10e5a39 |


### Contracts Description Table


|  Contract  |         Type        |       Bases      |                  |                 |
|:----------:|:-------------------:|:----------------:|:----------------:|:---------------:|
|     └      |  **Function Name**  |  **Visibility**  |  **Mutability**  |  **Modifiers**  |
||||||
| **DocumentEngineBase** | Implementation | IERC1643, IERC1643MultiDocument, DocumentEngineInvariant, Context |||
| └ | _authorizeDocumentManagement | Internal 🔒 |   | |
| └ | _authorizeBoundTokenDocumentManagement | Internal 🔒 |   | |
| └ | setDocument | Public ❗️ | 🛑  | onlyDocumentManager |
| └ | removeDocument | External ❗️ | 🛑  | onlyDocumentManager |
| └ | setDocument | External ❗️ | 🛑  | onlyBoundToken |
| └ | removeDocument | External ❗️ | 🛑  | onlyBoundToken |
| └ | batchSetDocuments | External ❗️ | 🛑  | onlyDocumentManager |
| └ | batchSetDocuments | External ❗️ | 🛑  | onlyDocumentManager |
| └ | batchRemoveDocuments | External ❗️ | 🛑  | onlyDocumentManager |
| └ | batchRemoveDocuments | External ❗️ | 🛑  | onlyDocumentManager |
| └ | getDocument | External ❗️ |   |NO❗️ |
| └ | getDocument | External ❗️ |   |NO❗️ |
| └ | getAllDocuments | External ❗️ |   |NO❗️ |
| └ | getAllDocuments | External ❗️ |   |NO❗️ |
| └ | _getDocument | Internal 🔒 |   | |
| └ | _removeDocumentName | Internal 🔒 | 🛑  | |
| └ | _removeDocument | Internal 🔒 | 🛑  | |
| └ | _setDocument | Internal 🔒 | 🛑  | |


### Legend

|  Symbol  |  Meaning  |
|:--------:|-----------|
|    🛑    | Function can modify state |
|    💵    | Function is payable |

## Sūrya's Description Report

### Files Description Table


|  File Name  |  SHA-1 Hash  |
|-------------|--------------|
| ./DocumentEngineBase.sol | 2c5a7b3ace8bd7e83ea19b1d53dc833fc4ec5349 |


### Contracts Description Table


|  Contract  |         Type        |       Bases      |                  |                 |
|:----------:|:-------------------:|:----------------:|:----------------:|:---------------:|
|     └      |  **Function Name**  |  **Visibility**  |  **Mutability**  |  **Modifiers**  |
||||||
| **DocumentEngineBase** | Implementation | IERC1643, IERC1643MultiDocument, DocumentEngineInvariant, Context |||
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
| └ | setDocument | Public ❗️ | 🛑  | onlyDocumentManager |
| └ | _removeDocumentName | Internal 🔒 | 🛑  | |
| └ | _removeDocument | Internal 🔒 | 🛑  | |
| └ | _setDocument | Internal 🔒 | 🛑  | |
| └ | _authorizeDocumentManagement | Internal 🔒 |   | |
| └ | _authorizeBoundTokenDocumentManagement | Internal 🔒 |   | |
| └ | _getDocument | Internal 🔒 |   | |


### Legend

|  Symbol  |  Meaning  |
|:--------:|-----------|
|    🛑    | Function can modify state |
|    💵    | Function is payable |

## Sūrya's Description Report

### Files Description Table


|  File Name  |  SHA-1 Hash  |
|-------------|--------------|
| ./DocumentEngine.sol | [object Promise] |


### Contracts Description Table


|  Contract  |         Type        |       Bases      |                  |                 |
|:----------:|:-------------------:|:----------------:|:----------------:|:---------------:|
|     └      |  **Function Name**  |  **Visibility**  |  **Mutability**  |  **Modifiers**  |
||||||
| **DocumentEngine** | Implementation | IERC1643, DocumentEngineInvariant, AccessControl, ERC2771Context |||
| └ | <Constructor> | Public ❗️ | 🛑  | ERC2771Context |
| └ | setDocument | Public ❗️ | 🛑  | onlyRole |
| └ | removeDocument | External ❗️ | 🛑  | onlyRole |
| └ | batchSetDocuments | External ❗️ | 🛑  | onlyRole |
| └ | batchSetDocuments | External ❗️ | 🛑  | onlyRole |
| └ | batchRemoveDocuments | External ❗️ | 🛑  | onlyRole |
| └ | batchRemoveDocuments | External ❗️ | 🛑  | onlyRole |
| └ | getDocument | External ❗️ |   |NO❗️ |
| └ | getDocument | External ❗️ |   |NO❗️ |
| └ | getAllDocuments | External ❗️ |   |NO❗️ |
| └ | getAllDocuments | External ❗️ |   |NO❗️ |
| └ | hasRole | Public ❗️ |   |NO❗️ |
| └ | _getDocument | Internal 🔒 |   | |
| └ | _removeDocumentName | Internal 🔒 | 🛑  | |
| └ | _removeDocument | Internal 🔒 | 🛑  | |
| └ | _setDocument | Internal 🔒 | 🛑  | |
| └ | _msgSender | Internal 🔒 |   | |
| └ | _msgData | Internal 🔒 |   | |
| └ | _contextSuffixLength | Internal 🔒 |   | |


### Legend

|  Symbol  |  Meaning  |
|:--------:|-----------|
|    🛑    | Function can modify state |
|    💵    | Function is payable |

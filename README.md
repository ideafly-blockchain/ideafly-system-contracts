# nddn-system-contracts

This repository contains the implementation code for the NDDN system contracts, and the contract compilation and testing scripts.

## Prerequisites

The core of this project is Solidity smart contracts. Compilation and testing depend on the Node.js environment and the Hardhat framework.

Basic dependency installation: You must install `Node.js` (version requirement: `^16.20 || ^18.16 || >=20`) and the package management tool `Yarn`. Installation instructions can be referred to in the following official documents:

- [download node.js](https://nodejs.org/download/release/v18.18.2/) or [Installing Node.js via package manager](https://nodejs.org/en/download/package-manager)
- [yarn installation](https://classic.yarnpkg.com/en/docs/install)

After installing the basic dependencies, run the following command to install project dependencies:

```bash
yarn
```

## Compilation and Testing

Test:

```bash
yarn test
```

Clean old compile:
```bash
yarn clean
```

Compile (In order to facilitate testing, some pre-compile directives have been set in the smart contract code to use some Mock contracts during testing, so the following command must be used for formal compilation to ensure the correct compilation results):

```bash
yarn compile
```

## How to use in NDDN

- Run the command `yarn compile` to compile the contracts, then the final contracts will be generated to directory `cache/solpp-generated-contracts/`, and the compile result can be found at `artifacts/cache/solpp-generated-contracts/`, each contract will have a correspondent json file.
- Get the `deployedBytecode` of the target contracts, set then to the `genesis file` of the blockchain.
- System contracts at the `genesis file` have predefined addresses as follows:
    - ValidatorsContractAddr  : "0x000000000000000000000000000000000000d001"
    - PunishContractAddr      : "0x000000000000000000000000000000000000D002"
    - SysGovContractAddr      : "0x000000000000000000000000000000000000D003"
    - AddressListContractAddr : "0x000000000000000000000000000000000000D004"

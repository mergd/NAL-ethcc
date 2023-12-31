<img align="right" width="150" height="150" top="100" src="./public/readme.jpg">

zkevm:
Deployed LoanCoordinator at address 0xc6e0b3bF7183e5D6dC9fA24eA82A934C7231aED1
Deployed NALToken at address 0x49feD5Dedf1c0f563f273c3026C59782a1D693D5
Deployed NGMIToken at address 0x8A819536568A75D2f817e89A119c6E17Aa2dd557
Deployed VoteContract at address 0x833fB3E35521D9e62c53C34C27CF7745a6060596
Deployed Loans at address 0xF9f69678F66212d65fA5365739C3b5781c2813D6

Celo Alfajores:
== Logs ==
Deployed LoanCoordinator at address 0xc6e0b3bF7183e5D6dC9fA24eA82A934C7231aED1
Deployed NALToken at address 0x49feD5Dedf1c0f563f273c3026C59782a1D693D5
Deployed NGMIToken at address 0x8A819536568A75D2f817e89A119c6E17Aa2dd557
Deployed VoteContract at address 0x833fB3E35521D9e62c53C34C27CF7745a6060596
Deployed Loans at address 0xF9f69678F66212d65fA5365739C3b5781c2813D6

linea
== Logs ==
Deployed LoanCoordinator at address 0xc6e0b3bF7183e5D6dC9fA24eA82A934C7231aED1
Deployed NALToken at address 0x49feD5Dedf1c0f563f273c3026C59782a1D693D5
Deployed NGMIToken at address 0x8A819536568A75D2f817e89A119c6E17Aa2dd557
Deployed VoteContract at address 0x833fB3E35521D9e62c53C34C27CF7745a6060596
Deployed Loans at address 0xF9f69678F66212d65fA5365739C3b5781c2813D6

Sepolia:
coordinator 0x49feD5Dedf1c0f563f273c3026C59782a1D693D5
NAL 0xF9f69678F66212d65fA5365739C3b5781c2813D6
NGMI 0x44A29D4b39dC7256393E9e7F34F5284C0EBA2f07
Vote 0x76e83079Ef320ae72D5A53AFa39BECFc6346108a

Mantle Testnet:
== Logs ==
Deployed LoanCoordinator at address 0xc6e0b3bF7183e5D6dC9fA24eA82A934C7231aED1
Deployed NALToken at address 0x49feD5Dedf1c0f563f273c3026C59782a1D693D5
Deployed NGMIToken at address 0x8A819536568A75D2f817e89A119c6E17Aa2dd557
Deployed VoteContract at address 0x833fB3E35521D9e62c53C34C27CF7745a6060596
Deployed MockERC20 at address 0xF9f69678F66212d65fA5365739C3b5781c2813D6
Deployed PSMArranger at address 0x44A29D4b39dC7256393E9e7F34F5284C0EBA2f07
Deployed Loans at address 0x76e83079Ef320ae72D5A53AFa39BECFc6346108a

# femplate • [![tests](https://github.com/refcell/femplate/actions/workflows/ci.yml/badge.svg?label=tests)](https://github.com/refcell/femplate/actions/workflows/ci.yml) ![license](https://img.shields.io/github/license/refcell/femplate?label=license) ![solidity](https://img.shields.io/badge/solidity-^0.8.17-lightgrey)

A **Clean**, **Robust** Template for Foundry Projects.

### Usage

**Building & Testing**

Build the foundry project with `forge build`. Then you can run tests with `forge test`.

**Deployment & Verification**

Inside the [`utils/`](./utils/) directory are a few preconfigured scripts that can be used to deploy and verify contracts.

Scripts take inputs from the cli, using silent mode to hide any sensitive information.

_NOTE: These scripts are required to be \_executable_ meaning they must be made executable by running `chmod +x ./utils/*`.\_

_NOTE: these scripts will prompt you for the contract name and deployed addresses (when verifying). Also, they use the `-i` flag on `forge` to ask for your private key for deployment. This uses silent mode which keeps your private key from being printed to the console (and visible in logs)._

### I'm new, how do I get started?

We created a guide to get you started with: [GETTING_STARTED.md](./GETTING_STARTED.md).

### Blueprint

```txt
lib
├─ forge-std — https://github.com/foundry-rs/forge-std
├─ solmate — https://github.com/transmissions11/solmate
scripts
├─ Deploy.s.sol — Example Contract Deployment Script
src
├─ Greeter — Example Contract
test
└─ Greeter.t — Example Contract Tests
```

### Notable Mentions

- [femplate](https://github.com/refcell/femplate)
- [foundry](https://github.com/foundry-rs/foundry)
- [solmate](https://github.com/Rari-Capital/solmate)
- [forge-std](https://github.com/brockelmore/forge-std)
- [forge-template](https://github.com/foundry-rs/forge-template)
- [foundry-toolchain](https://github.com/foundry-rs/foundry-toolchain)

### Disclaimer

_These smart contracts are being provided as is. No guarantee, representation or warranty is being made, express or implied, as to the safety or correctness of the user interface or the smart contracts. They have not been audited and as such there can be no assurance they will work as intended, and users may experience delays, failures, errors, omissions, loss of transmitted information or loss of funds. The creators are not liable for any of the foregoing. Users should proceed with caution and use at their own risk._

See [LICENSE](./LICENSE) for more details.

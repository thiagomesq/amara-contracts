# Amara

Amara is a decentralized platform that helps organizations register entities and receive transparent on-chain contributions. The protocol combines permissioned organization and entity management, controlled ERC-721 asset issuance, and ERC-20 contribution flows.

> **Network status:** The protocol is deployed on **Linea Sepolia** for testing. It is not production-ready and must not be used with real funds or sensitive personal data.

## Deployed contracts

The current deployment uses upgradeable UUPS implementations behind ERC-1967 proxies. Application integrations must call the **proxy addresses**, not the implementation addresses.

- **Network:** Linea Sepolia
- **Chain ID:** `59141`
- **Explorer:** [LineaScan Sepolia](https://sepolia.lineascan.build/)
- **Registry:** [`0x13fa60087401d1c273d4e9ce863a29838ec60566`](https://sepolia.lineascan.build/address/0x13fa60087401d1c273d4e9ce863a29838ec60566)

| Module | Proxy, use for integration | Implementation |
| --- | --- | --- |
| OrganizationManager | [`0xd1025133518cbac5b3f65bb9c82dd022784be3aa`](https://sepolia.lineascan.build/address/0xd1025133518cbac5b3f65bb9c82dd022784be3aa) | [`0x46ed8995b81ede69aae3e2b399fcf0cc72eed8d3`](https://sepolia.lineascan.build/address/0x46ed8995b81ede69aae3e2b399fcf0cc72eed8d3) |
| EntityManager | [`0x3e0b80c7787eca08db0cbb17550bd4db3ce5284f`](https://sepolia.lineascan.build/address/0x3e0b80c7787eca08db0cbb17550bd4db3ce5284f) | [`0xa830a74354194a25BB707b2Ce43A87157126268F`](https://sepolia.lineascan.build/address/0xa830a74354194a25BB707b2Ce43A87157126268F) |
| EntityToken | [`0x2c763da9c55ec276721edb1dfd25d915de7e957d`](https://sepolia.lineascan.build/address/0x2c763da9c55ec276721edb1dfd25d915de7e957d) | [`0xb15eb6ec3E3B8FD6a546B84737bBb7c4C3903A07`](https://sepolia.lineascan.build/address/0xb15eb6ec3E3B8FD6a546B84737bBb7c4C3903A07) |
| Contribution | [`0x70bee8dd08fcb77727f7831aecb118196b6377e3`](https://sepolia.lineascan.build/address/0x70bee8dd08fcb77727f7831aecb118196b6377e3) | [`0xC408C259b1fc4E6CF6293D681192760BA3edACF8`](https://sepolia.lineascan.build/address/0xC408C259b1fc4E6CF6293D681192760BA3edACF8) |

## Architecture

The protocol is organized into modular contracts:

- **Registry:** Stores the active addresses of protocol modules under `bytes32` identifiers.
- **OrganizationManager:** Registers organizations, associates each organization with a controlling wallet, and lets an administrator approve organizations.
- **EntityManager:** Lets approved organizations register entities linked to off-chain data hashes and coordinates controlled token issuance.
- **EntityToken:** An upgradeable ERC-721 token that represents an entity-linked digital asset. Minting and metadata updates are role-gated.
- **Contribution:** Handles ERC-20 contributions and recurring subscriptions using EIP-2612 permits, SafeERC20 transfers, configurable service fees, and reentrancy protection.

## Current capabilities

- Organization registration and administrative approval.
- Entity registration tied to a `bytes32` off-chain data hash.
- Role-gated ERC-721 minting and metadata updates.
- ERC-20 contribution flows using EIP-2612 `permit`.
- Recurring contribution subscriptions.
- UUPS upgrade authorization controlled through `DEFAULT_ADMIN_ROLE`.
- ERC-1967 proxy deployment and registry-based module discovery.

## Important integration notes

- Use the proxy addresses in the deployment table for reads and writes.
- The implementation contracts are not the user-facing integration targets.
- Contract addresses are recorded in the Registry after deployment.
- The deployment script initializes proxies in separate transactions. Before a production deployment, initialization should be encoded in each `ERC1967Proxy` constructor call to make deployment and initialization atomic.
- The current ERC-721 implementation controls minting, but it does not yet enforce escrow-only transfers. Do not describe it as a complete restricted-transfer or ERC-3643 implementation.

## Development setup

### Prerequisites

- [Node.js](https://nodejs.org/) 20 or later
- [pnpm](https://pnpm.io/)
- Foundry for contract development, testing, and deployments

### Application setup

```bash
git clone <REPOSITORY_URL>
cd amaras-app
pnpm install
```

Create `.env.local`:

```env
NEXT_PUBLIC_FIREBASE_API_KEY="..."
NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN="..."
NEXT_PUBLIC_FIREBASE_PROJECT_ID="..."
NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET="..."
NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID="..."
NEXT_PUBLIC_FIREBASE_APP_ID="..."
NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID="..."

# Test account only. Never expose a production private key in the frontend.
PRIVATE_KEY="0x..."
```

Run the application:

```bash
pnpm run dev
```

The local application is available at [http://localhost:3000](http://localhost:3000).

## Production hardening roadmap

The Linea Sepolia deployment is an engineering test environment. The following work is required before production use:

- Encode proxy initializer calldata during proxy construction.
- Move administrative, upgrade, and emergency authority to a multisig with separated roles.
- Add `PausableUpgradeable` controls to asset-moving and settlement-critical operations.
- Add comprehensive Foundry unit, fuzz, invariant, and integration tests.
- Add an independent security review and audit before handling real assets or funds.
- Define monitoring, alerts, upgrade procedures, key rotation, and incident runbooks.
- Complete the restricted-transfer and escrow design if the protocol is used for regulated or title-like assets.

## Security notice

This repository and its Linea Sepolia contracts are for development and testing. They have not been independently audited. Do not use them to custody real assets, process real donations, or store personally identifiable information on-chain.

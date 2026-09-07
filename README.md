# 🔗 Blockchain Identity Platform — Smart Contracts

> Built for **SIH 2026** | Solidity + Hardhat + Polygon

Smart contracts for a blockchain-powered digital identity and asset ownership platform.

---

## 📄 Contract — DigitalAsset.sol

Handles everything on-chain:
- Mint digital assets (gold, stocks, crypto, certificates) as NFTs
- Only admins can mint — no fakes possible
- Every asset linked to owner's wallet address
- Asset revocation by admin
- Full on-chain audit trail

---

## 🛠️ Tech Stack

- **Solidity** — Smart contract language
- **Hardhat** — Development + testing framework
- **Polygon Testnet** — Deployment network
- **ethers.js** — Blockchain interaction

---

## ⚙️ Setup Instructions

### 1. Clone the repo
git clone https://github.com/ssbparth/blockchain-contracts
cd blockchain-contracts


### 2. Install dependencies
npm install


### 3. Start local blockchain
npx hardhat node

### 4. Deploy contract (on new terminal)
npx hardhat run scripts/deploy.js --network localhost


### 5. Copy contract address
After deploy you will see:
DigitalAsset deployed to: 0x...

Add this address to your backend `.env` file as `CONTRACT_ADDRESS`

---

## 📦 Contract Functions

| Function | Access | Description |
|----------|--------|-------------|
| `mintAsset()` | Admin only | Mint a new digital asset NFT |
| `getOwnerAssets()` | Public | Get all assets of a wallet |
| `revokeAsset()` | Admin only | Revoke/invalidate an asset |
| `addAdmin()` | Super Admin | Add a new admin |

---

## 🔗 Related Repos

- [Backend API](https://github.com/ssbparth/blockchain) — FastAPI backend

# Welcome Home Property - Real Estate Tokenization Platform

## Project Overview

Welcome Home Property is a **decentralized real estate tokenization platform** built with Solidity and deployed on **Hedera Testnet**. The platform enables:

- Property tokenization (fractional real estate ownership)
- KYC-gated token distribution and trading
- Secondary marketplace for property tokens
- Dividend distribution to token holders
- Role-based access control (Admin, Property Manager, KYC verification)

**Target Network**: Hedera Testnet (Chain ID: 296)
**Current Deployment**: Fully deployed and operational on testnet

---

## Tech Stack

### Smart Contract Layer
- **Language**: Solidity ^0.8.19
- **Framework**: Foundry (Forge, Cast, Anvil)
- **Testing**: Forge tests with comprehensive integration tests
- **Libraries**: 
  - OpenZeppelin Contracts (ERC20, Ownable, ReentrancyGuard)
  - forge-std (testing utilities)

### Blockchain Network
- **Network**: Hedera Testnet
- **RPC**: https://testnet.hashio.io/api
- **Explorer**: https://hashscan.io/testnet
- **Chain ID**: 296
- **Native Currency**: HBAR

### Development Tools
- Foundry toolchain (forge, cast, anvil)
- Bash scripts for deployment automation
- JSON-based deployment tracking

---

## Project Structure

```
buner-welcome/
├── src/                          # Smart contracts
│   ├── AccessControl.sol         # Role & KYC management
│   ├── OwnershipRegistry.sol     # Token holder tracking
│   ├── PropertyFactory.sol       # Property creation & management
│   ├── PropertyToken.sol         # ERC20 property tokens with dividends
│   └── Marketplace.sol           # Trading platform with fees
│
├── script/                       # Deployment & utility scripts
│   ├── 01-13_*.s.sol            # Atomic deployment scripts (1 tx each)
│   ├── verify_*.s.sol           # System verification scripts
│   └── simple_test_*.s.sol      # Manual testing scripts
│
├── test/                         # Comprehensive test suite
│   ├── AccessControl.t.sol       # Access control unit tests
│   ├── OwnershipRegistry.t.sol   # Registry unit tests
│   ├── PropertyFactory.t.sol     # Factory unit tests
│   ├── PropertyToken.t.sol       # Token unit tests
│   ├── Marketplace.t.sol         # Marketplace unit tests
│   └── Integration.t.sol         # End-to-end integration tests
│
├── lib/                          # Dependencies (git submodules)
│   ├── forge-std/               # Foundry standard library
│   └── openzeppelin-contracts/  # OpenZeppelin contracts
│
├── broadcast/                    # Deployment transaction logs
├── cache/                        # Forge build cache
├── out/                          # Compiled contract artifacts
│
├── foundry.toml                  # Foundry configuration
├── deploy_all.sh                 # Automated deployment runner
├── deployment_step_*.json        # Deployment tracking files
├── DEPLOYMENT_GUIDE.md           # Detailed deployment instructions
└── FRONTEND_INTEGRATION.md       # Frontend integration guide
```

---

## Core Architecture

### Contract Hierarchy & Responsibilities

#### 1. AccessControl (Core Security Layer)
**Purpose**: Centralized permission and KYC management

**Key Features**:
- Role management (Admin, Property Manager)
- KYC verification status tracking
- System pause functionality
- Emergency transfer override capability

**Roles**:
- **Owner**: Highest privilege (set admins)
- **Admin**: Manage KYC, property managers, system pause
- **Property Manager**: Create properties, distribute tokens

**Critical Functions**:
- `setKYCStatus()` - KYC verification (admin only)
- `setAdmin()` - Grant/revoke admin (owner only)
- `setPropertyManager()` - Grant/revoke property manager (admin only)
- `pauseSystem()` / `unpauseSystem()` - Emergency pause

---

#### 2. OwnershipRegistry (Token Holder Tracking)
**Purpose**: Track all property token holders across the platform

**Key Features**:
- Cross-contract token holder tracking
- Authorized updater pattern (only property tokens can update)
- Efficient holder enumeration
- Balance tracking per token per holder

**Critical Functions**:
- `updateOwnership()` - Called by PropertyToken on transfers
- `getTokenHolders()` - Get all holders of a property token
- `setAuthorizedUpdater()` - Authorize new property tokens

---

#### 3. PropertyFactory (Property Management)
**Purpose**: Create and manage tokenized properties

**Key Features**:
- Creates PropertyToken contracts dynamically
- Distributes tokens to KYC-verified investors (primary offering)
- Property metadata management (IPFS URIs)
- Price and status management

**Property Creation Flow**:
1. Property manager calls `createProperty()`
2. Factory deploys new PropertyToken contract
3. Factory registers token with OwnershipRegistry
4. All tokens initially minted to factory
5. Property manager distributes via `distributeTokens()`

**Critical Functions**:
- `createProperty()` - Deploy new property (property manager only)
- `distributeTokens()` - Primary distribution to KYC users
- `updatePropertyMetadata()` - Update property details
- `setPropertyActive()` - Enable/disable property

---

#### 4. PropertyToken (ERC20 with Extensions)
**Purpose**: Represents fractional ownership of real estate

**Key Features**:
- Standard ERC20 functionality
- KYC-gated transfers (buyers must be verified)
- Dividend distribution and claiming
- Admin transfer override (emergency)
- Trading enable/disable flag

**Transfer Rules**:
- Recipient MUST be KYC-verified
- Trading must be enabled
- System must not be paused
- No transfer restrictions on user

**Dividend Mechanism**:
- Property manager deposits HBAR via `distributeDividends()`
- Dividends tracked per token holder
- Users claim via `claimDividends()`
- Proportional to token holdings

---

#### 5. Marketplace (Secondary Trading)
**Purpose**: Peer-to-peer trading of property tokens

**Key Features**:
- Create sell listings (requires token approval)
- Direct purchase from listings
- Offer/counter-offer mechanism
- Platform fee (2.5% default)
- KYC-gated participation

**Trading Flow**:
1. Seller approves Marketplace to spend tokens
2. Seller creates listing with `createListing()`
3. Buyer purchases with `buyFromListing()` (sends HBAR)
4. Marketplace takes 2.5% fee
5. Tokens transferred to buyer, HBAR to seller

**Critical Functions**:
- `createListing()` - Seller lists tokens
- `buyFromListing()` - Direct purchase
- `createOffer()` - Make offer on listing
- `acceptOffer()` - Seller accepts offer
- `setPlatformFee()` - Admin sets fee

---

## Key Patterns & Conventions

### 1. Single Transaction Per Script
**Why**: Hedera can drop transactions from mempool if too many sent at once

**Pattern**:
- Each deployment script (`01-13_*.s.sol`) sends exactly 1 transaction
- 5-second delays between scripts via `deploy_all.sh`
- JSON files track deployment progress

**Example**:
```solidity
// 01_deploy_access_control.s.sol
vm.startBroadcast(deployerPrivateKey);
AccessControl accessControl = new AccessControl(); // ONLY transaction
vm.stopBroadcast();
vm.writeFile("deployment_step_1.json", ...); // Off-chain tracking
```

---

### 2. KYC-Gated Operations
**Pattern**: All token transfers require recipient KYC verification

**Implementation**:
```solidity
// In PropertyToken.sol
function transfer(address to, uint256 amount) public override {
    require(accessControl.isUserKYCed(to), "Recipient not KYC verified");
    // ... rest of transfer logic
}
```

**Applies to**:
- Token transfers (primary & secondary)
- Token distributions from factory
- Marketplace purchases
- Dividend claims

---

### 3. Modifier Chaining
**Pattern**: Multiple security checks via modifiers

**Example**:
```solidity
function distributeTokens(uint256 propertyId, address to, uint256 amount)
    external
    validProperty(propertyId)      // Property exists check
    onlyPropertyManager            // Role check
    whenNotPaused                  // System state check
    nonReentrant                   // Reentrancy protection
{
    require(accessControl.isUserKYCed(to), "Recipient not KYC verified");
    // ... function logic
}
```

---

### 4. Authorized Updater Pattern
**Pattern**: Only specific contracts can call sensitive functions

**Used in**: OwnershipRegistry

**Implementation**:
```solidity
modifier onlyAuthorizedUpdater() {
    require(authorizedUpdaters[msg.sender], "Not authorized updater");
    _;
}

function updateOwnership(address token, address holder, uint256 balance)
    external
    onlyAuthorizedUpdater
{
    // ... update logic
}
```

---

### 5. Comprehensive Event Logging
**Pattern**: Emit events for all state changes

**Purpose**: Frontend tracking, analytics, audit trail

**Example**:
```solidity
event PropertyCreated(
    uint256 indexed propertyId,
    string name,
    address indexed tokenContract,
    address indexed creator
);
```

---

### 6. Emergency Admin Controls
**Pattern**: Admin override functions for crisis management

**Examples**:
- `pauseSystem()` - Freeze all platform activity
- `adminTransfer()` - Force token transfer (in PropertyToken)
- `emergencyTransferOverride()` - Cross-contract emergency transfer

**Security**: Only callable by admin role, emits events for transparency

---

## Development Commands

### Setup & Installation
```bash
# Install Foundry (if not installed)
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Clone and setup project
git clone <repo>
cd buner-welcome
git submodule update --init --recursive
```

### Environment Configuration
```bash
# Create .env file
cat > .env << EOF
HEDERA_RPC_URL=https://testnet.hashio.io/api
HEDERA_PRIVATE_KEY=0xYOUR_PRIVATE_KEY_HERE

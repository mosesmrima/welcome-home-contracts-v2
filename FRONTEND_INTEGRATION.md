# Welcome Home Property - Frontend Integration Guide

## 🏠 Platform Overview

Welcome Home Property is a real estate tokenization platform deployed on **Hedera Testnet** that allows users to:
- Create tokenized real estate properties
- Distribute property tokens to investors
- Trade property tokens on an integrated marketplace
- Manage KYC verification and access control

---

## 🔗 Deployed Contract Addresses (Hedera Testnet)

| Contract | Address | Purpose |
|----------|---------|---------|
| **AccessControl** | `0xa53A31b1fA483DEc156575EFbd0233C3bb14F54e` | User roles, KYC, system pause |
| **OwnershipRegistry** | `0x6D02419484F0587d21a27600048826dA8ee9D155` | Track token holders |
| **PropertyFactory** | `0x9e3CF47Cb63f33BA726985537097bA04a18E1bF0` | Create property tokens |
| **Marketplace** | `0x74189ff22BF4aa4a5CEc193405ed125b48EaC478` | Buy/sell property tokens |

### Network Configuration:
- **Network**: Hedera Testnet
- **Chain ID**: 296
- **RPC URL**: `https://testnet.hashio.io/api`
- **Explorer**: https://hashscan.io/testnet

---

## 🚀 Quick Setup

### 1. Install Dependencies

```bash
npm install ethers @hashgraph/sdk wagmi viem
```

### 2. Network Configuration

```javascript
// wagmi.config.js
import { defineConfig } from '@wagmi/cli'

export const hederaTestnet = {
  id: 296,
  name: 'Hedera Testnet',
  network: 'hedera-testnet',
  nativeCurrency: {
    decimals: 18,
    name: 'HBAR',
    symbol: 'HBAR',
  },
  rpcUrls: {
    public: { http: ['https://testnet.hashio.io/api'] },
    default: { http: ['https://testnet.hashio.io/api'] },
  },
  blockExplorers: {
    default: { name: 'HashScan', url: 'https://hashscan.io/testnet' },
  },
}
```

### 3. Contract ABIs & Addresses

```javascript
// contracts.js
export const CONTRACTS = {
  AccessControl: {
    address: '0xa53A31b1fA483DEc156575EFbd0233C3bb14F54e',
    abi: [
      'function isUserAdmin(address user) external view returns (bool)',
      'function isUserPropertyManager(address user) external view returns (bool)',
      'function isUserKYCed(address user) external view returns (bool)',
      'function isSystemPaused() external view returns (bool)',
      'function setKYCStatus(address user, bool status) external',
      'function setAdmin(address user, bool status) external',
      'function setPropertyManager(address user, bool status) external'
    ]
  },
  PropertyFactory: {
    address: '0x9e3CF47Cb63f33BA726985537097bA04a18E1bF0',
    abi: [
      'function createProperty(string memory name, string memory metadataURI, uint256 totalValue, uint256 totalSupply, uint256 pricePerToken) external returns (uint256)',
      'function distributeTokens(uint256 propertyId, address to, uint256 amount) external',
      'function nextPropertyId() external view returns (uint256)',
      'function getActivePropertyCount() external view returns (uint256)',
      'function properties(uint256 id) external view returns (uint256, string memory, string memory, address, uint256, uint256, uint256, bool, address, uint256)',
      'function getPropertiesByCreator(address creator) external view returns (uint256[] memory)'
    ]
  },
  Marketplace: {
    address: '0x74189ff22BF4aa4a5CEc193405ed125b48EaC478',
    abi: [
      'function createListing(address tokenContract, uint256 amount, uint256 pricePerToken) external returns (uint256)',
      'function buyFromListing(uint256 listingId, uint256 amount) external payable',
      'function createOffer(uint256 listingId, uint256 amount, uint256 pricePerToken) external payable returns (uint256)',
      'function cancelListing(uint256 listingId) external',
      'function listings(uint256 id) external view returns (uint256, address, address, uint256, uint256, bool, uint256)',
      'function nextListingId() external view returns (uint256)',
      'function getUserListings(address user) external view returns (uint256[] memory)',
      'function platformFeePercent() external view returns (uint256)'
    ]
  },
  PropertyToken: {
    abi: [
      'function name() external view returns (string memory)',
      'function symbol() external view returns (string memory)',
      'function totalSupply() external view returns (uint256)',
      'function balanceOf(address account) external view returns (uint256)',
      'function transfer(address to, uint256 amount) external returns (bool)',
      'function approve(address spender, uint256 amount) external returns (bool)',
      'function allowance(address owner, address spender) external view returns (uint256)',
      'function distributeDividends() external payable',
      'function claimDividends() external returns (uint256)',
      'function getClaimableDividends(address user) external view returns (uint256)'
    ]
  }
}
```

---

## 📋 User Flow & Integration Guide

### Phase 1: User Onboarding & KYC

#### 1.1 Connect Wallet
```javascript
// Connect to Hedera Testnet
import { useAccount, useConnect, useDisconnect } from 'wagmi'

function WalletConnection() {
  const { address, isConnected } = useAccount()
  const { connect, connectors } = useConnect()
  const { disconnect } = useDisconnect()

  return (
    <div>
      {isConnected ? (
        <div>
          <p>Connected: {address}</p>
          <button onClick={() => disconnect()}>Disconnect</button>
        </div>
      ) : (
        <button onClick={() => connect({ connector: connectors[0] })}>
          Connect Wallet
        </button>
      )}
    </div>
  )
}
```

#### 1.2 Check KYC Status
```javascript
// Check if user is KYC verified
import { useContractRead } from 'wagmi'

function useKYCStatus(userAddress) {
  return useContractRead({
    address: CONTRACTS.AccessControl.address,
    abi: CONTRACTS.AccessControl.abi,
    functionName: 'isUserKYCed',
    args: [userAddress],
    enabled: !!userAddress,
  })
}
```

#### 1.3 Check User Roles
```javascript
function useUserRoles(userAddress) {
  const { data: isAdmin } = useContractRead({
    address: CONTRACTS.AccessControl.address,
    abi: CONTRACTS.AccessControl.abi,
    functionName: 'isUserAdmin',
    args: [userAddress],
  })

  const { data: isPropertyManager } = useContractRead({
    address: CONTRACTS.AccessControl.address,
    abi: CONTRACTS.AccessControl.abi,
    functionName: 'isUserPropertyManager',
    args: [userAddress],
  })

  const { data: isKYCed } = useContractRead({
    address: CONTRACTS.AccessControl.address,
    abi: CONTRACTS.AccessControl.abi,
    functionName: 'isUserKYCed',
    args: [userAddress],
  })

  return { isAdmin, isPropertyManager, isKYCed }
}
```

### Phase 2: Property Creation (Property Managers Only)

#### 2.1 Create Property
```javascript
import { useContractWrite } from 'wagmi'

function useCreateProperty() {
  return useContractWrite({
    address: CONTRACTS.PropertyFactory.address,
    abi: CONTRACTS.PropertyFactory.abi,
    functionName: 'createProperty',
  })
}

// Usage Example
function CreatePropertyForm() {
  const { write: createProperty, isLoading } = useCreateProperty()

  const handleSubmit = (formData) => {
    const totalSupply = parseEther(formData.totalSupply.toString())
    const pricePerToken = parseEther(formData.pricePerToken.toString())
    const totalValue = (totalSupply * pricePerToken) / parseEther('1')

    createProperty({
      args: [
        formData.name,
        formData.metadataURI,
        totalValue,
        totalSupply,
        pricePerToken
      ]
    })
  }

  return (
    <form onSubmit={handleSubmit}>
      {/* Property creation form */}
    </form>
  )
}
```

#### 2.2 Get Properties
```javascript
function useProperties() {
  const { data: totalProperties } = useContractRead({
    address: CONTRACTS.PropertyFactory.address,
    abi: CONTRACTS.PropertyFactory.abi,
    functionName: 'nextPropertyId',
  })

  // Fetch individual properties
  const properties = []
  for (let i = 0; i < (totalProperties || 0); i++) {
    const { data: property } = useContractRead({
      address: CONTRACTS.PropertyFactory.address,
      abi: CONTRACTS.PropertyFactory.abi,
      functionName: 'properties',
      args: [i],
    })
    if (property && property[7]) { // isActive
      properties.push({
        id: i,
        name: property[1],
        metadataURI: property[2],
        tokenContract: property[3],
        totalValue: property[4],
        totalSupply: property[5],
        pricePerToken: property[6],
        isActive: property[7],
        creator: property[8],
        createdAt: property[9]
      })
    }
  }

  return properties
}
```

#### 2.3 Distribute Tokens
```javascript
function useDistributeTokens() {
  return useContractWrite({
    address: CONTRACTS.PropertyFactory.address,
    abi: CONTRACTS.PropertyFactory.abi,
    functionName: 'distributeTokens',
  })
}

// Usage
function TokenDistribution({ propertyId }) {
  const { write: distributeTokens } = useDistributeTokens()

  const handleDistribute = (recipientAddress, amount) => {
    const tokenAmount = parseEther(amount.toString())
    distributeTokens({
      args: [propertyId, recipientAddress, tokenAmount]
    })
  }

  return (
    // Distribution form
  )
}
```

### Phase 3: Token Management

#### 3.1 Get Token Balance
```javascript
function useTokenBalance(tokenAddress, userAddress) {
  return useContractRead({
    address: tokenAddress,
    abi: CONTRACTS.PropertyToken.abi,
    functionName: 'balanceOf',
    args: [userAddress],
    enabled: !!(tokenAddress && userAddress),
  })
}
```

#### 3.2 Token Allowance & Approval
```javascript
function useTokenApproval(tokenAddress) {
  return useContractWrite({
    address: tokenAddress,
    abi: CONTRACTS.PropertyToken.abi,
    functionName: 'approve',
  })
}

// Usage for marketplace approval
function ApproveForMarketplace({ tokenAddress, amount }) {
  const { write: approve } = useTokenApproval(tokenAddress)

  const handleApprove = () => {
    approve({
      args: [CONTRACTS.Marketplace.address, parseEther(amount.toString())]
    })
  }

  return <button onClick={handleApprove}>Approve for Trading</button>
}
```

### Phase 4: Marketplace Integration

#### 4.1 Create Listing
```javascript
function useCreateListing() {
  return useContractWrite({
    address: CONTRACTS.Marketplace.address,
    abi: CONTRACTS.Marketplace.abi,
    functionName: 'createListing',
  })
}

// Complete listing flow
function CreateListing({ tokenAddress }) {
  const { write: approve } = useTokenApproval(tokenAddress)
  const { write: createListing } = useCreateListing()

  const handleCreateListing = async (amount, pricePerToken) => {
    // Step 1: Approve marketplace
    await approve({
      args: [CONTRACTS.Marketplace.address, parseEther(amount.toString())]
    })

    // Step 2: Create listing (after approval)
    setTimeout(() => {
      createListing({
        args: [
          tokenAddress,
          parseEther(amount.toString()),
          parseEther(pricePerToken.toString())
        ]
      })
    }, 5000) // Wait for approval transaction
  }

  return (
    // Listing creation form
  )
}
```

#### 4.2 Get Marketplace Listings
```javascript
function useMarketplaceListings() {
  const { data: totalListings } = useContractRead({
    address: CONTRACTS.Marketplace.address,
    abi: CONTRACTS.Marketplace.abi,
    functionName: 'nextListingId',
  })

  const listings = []
  for (let i = 0; i < (totalListings || 0); i++) {
    const { data: listing } = useContractRead({
      address: CONTRACTS.Marketplace.address,
      abi: CONTRACTS.Marketplace.abi,
      functionName: 'listings',
      args: [i],
    })
    if (listing && listing[5]) { // isActive
      listings.push({
        id: i,
        seller: listing[1],
        tokenContract: listing[2],
        amount: listing[3],
        pricePerToken: listing[4],
        isActive: listing[5],
        createdAt: listing[6]
      })
    }
  }

  return listings
}
```

#### 4.3 Buy from Listing
```javascript
function useBuyFromListing() {
  return useContractWrite({
    address: CONTRACTS.Marketplace.address,
    abi: CONTRACTS.Marketplace.abi,
    functionName: 'buyFromListing',
  })
}

function BuyTokens({ listingId, pricePerToken }) {
  const { write: buyFromListing } = useBuyFromListing()

  const handleBuy = (amount) => {
    const tokenAmount = parseEther(amount.toString())
    const totalCost = (tokenAmount * parseEther(pricePerToken.toString())) / parseEther('1')

    buyFromListing({
      args: [listingId, tokenAmount],
      value: totalCost
    })
  }

  return (
    // Buy form
  )
}
```

---

## 🔄 Complete User Workflows

### Workflow 1: Property Manager Creates Property

```javascript
// 1. Check if user is property manager
const { isPropertyManager } = useUserRoles(userAddress)

// 2. Create property (if authorized)
if (isPropertyManager) {
  createProperty({
    args: [name, metadataURI, totalValue, totalSupply, pricePerToken]
  })
}

// 3. Distribute tokens to investors
distributeTokens({
  args: [propertyId, investorAddress, tokenAmount]
})
```

### Workflow 2: Investor Buys Property Tokens

```javascript
// 1. Check KYC status
const { isKYCed } = useUserRoles(userAddress)

// 2. Browse marketplace listings
const listings = useMarketplaceListings()

// 3. Buy tokens (if KYC verified)
if (isKYCed) {
  buyFromListing({
    args: [listingId, tokenAmount],
    value: totalCost
  })
}
```

### Workflow 3: Token Holder Creates Listing

```javascript
// 1. Check token balance
const { data: balance } = useTokenBalance(tokenAddress, userAddress)

// 2. Approve marketplace
approve({
  args: [CONTRACTS.Marketplace.address, amountToSell]
})

// 3. Create listing
createListing({
  args: [tokenAddress, amountToSell, pricePerToken]
})
```

---

## 🔧 Advanced Features

### Dividend Management
```javascript
// Claim dividends from property token
function useClaimDividends(tokenAddress) {
  return useContractWrite({
    address: tokenAddress,
    abi: CONTRACTS.PropertyToken.abi,
    functionName: 'claimDividends',
  })
}

// Check claimable dividends
function useClaimableDividends(tokenAddress, userAddress) {
  return useContractRead({
    address: tokenAddress,
    abi: CONTRACTS.PropertyToken.abi,
    functionName: 'getClaimableDividends',
    args: [userAddress],
  })
}
```

### Portfolio Management
```javascript
function useUserPortfolio(userAddress) {
  const properties = useProperties()
  const portfolio = []

  properties.forEach((property) => {
    const { data: balance } = useTokenBalance(property.tokenContract, userAddress)
    if (balance && balance.gt(0)) {
      portfolio.push({
        ...property,
        userBalance: balance,
        userValue: balance.mul(property.pricePerToken).div(parseEther('1'))
      })
    }
  })

  return portfolio
}
```

---

## ⚠️ Important Notes

### Gas & Transaction Management
- Each script sends **exactly 1 transaction** to avoid mempool drops on Hedera
- Add 5-second delays between related transactions
- Always check transaction success before proceeding

### Security Considerations
- All token transfers require KYC verification
- Property creation requires Property Manager role
- System can be paused by admin in emergencies
- Platform takes 2.5% fee on marketplace transactions

### Testing Addresses
- **Deployer/Admin**: `0xD1B156294aFa63d7d174D06D5A83e547d7a5abA9`
- **Test Users**: `0x1111...1111`, `0x2222...2222`, `0x3333...3333` (KYC verified)

---

## 📞 Support

- **Explorer**: https://hashscan.io/testnet
- **Network**: Hedera Testnet (Chain ID: 296)
- **RPC**: https://testnet.hashio.io/api

Happy building! 🚀
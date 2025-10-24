# Base Sepolia Deployment Guide

## Prerequisites

1. **Base Sepolia Testnet Setup**

    - Get Base Sepolia ETH from [Base Sepolia Faucet](https://bridge.base.org/deposit)
    - Get LINK tokens from [Chainlink Faucet](https://faucets.chain.link/base-sepolia)

2. **Environment Variables**
   Create a `.env` file in your project root:
    ```bash
    PRIVATE_KEY=your_private_key_here
    BASE_SEPOLIA_RPC_URL=https://sepolia.base.org
    ETHERSCAN_API_KEY=your_etherscan_api_key_here
    ```

## VRF Subscription Setup

### Step 1: Create VRF Subscription

1. Go to [Chainlink VRF Subscription Manager](https://vrf.chain.link/base-sepolia)
2. Connect your wallet
3. Click "Create Subscription"
4. **Note**: No need to fund with LINK tokens - the contract uses native ETH payments
5. Copy your subscription ID

### Step 2: Update Deployment Script

**Important**: The subscription ID you provided (`104463245950711925848002979325066164966376483155872594786291361268349330657388`) is too large to fit in a `uint64`.

You have two options:

**Option 1: Create a New Subscription**

1. Go to [Chainlink VRF Subscription Manager](https://vrf.chain.link/base-sepolia)
2. Create a new subscription
3. The new subscription ID should be a smaller number that fits in uint64
4. Update the deployment script with the new subscription ID

**Option 2: Use the Current Subscription (Recommended)**
The current deployment script uses a placeholder subscription ID. You'll need to:

1. Deploy the contract with the placeholder ID
2. After deployment, call the `configureVRF` function to update the subscription ID
3. This allows you to use your large subscription ID

Update the `subscriptionId` in `script/DeployRaffle.s.sol`:

```solidity
uint64 subscriptionId = 1; // Placeholder - will be updated after deployment
```

## Deployment

### Step 1: Compile the Contract

```bash
forge build
```

### Step 2: Deploy to Base Sepolia

```bash
forge script script/DeployRaffle.s.sol --rpc-url $BASE_SEPOLIA_RPC_URL --broadcast --verify
```

### Step 3: Configure VRF (if using large subscription ID)

If you're using the large subscription ID, you need to configure it after deployment:

```solidity
// Call configureVRF function with your actual subscription ID
raffle.configureVRF(
    YOUR_ACTUAL_SUBSCRIPTION_ID, // Your large subscription ID
    keyHash,
    callbackGasLimit,
    requestConfirmations
);
```

### Step 4: Add Consumer to VRF Subscription

After deployment, you need to add your deployed contract as a consumer:

1. Go to [Chainlink VRF Subscription Manager](https://vrf.chain.link/base-sepolia)
2. Find your subscription
3. Click "Add Consumer"
4. Enter your deployed contract address
5. Confirm the transaction

## VRF Configuration Details

-   **VRF Coordinator**: `0x5C210eF41CD1a72de73bF76eC39637bB0d3d7BEE`
-   **LINK Token**: `0xE4aB69C077896252FAFBD49EFD26B5D171A32410`
-   **Key Hash**: `0x9e1344a1247c8a1785d0a4681a27152bffdb43666ae5bf7d14d24a5efd44bf71`
-   **Payment Method**: Native ETH (60% premium)
-   **Subscription ID**: `104463245950711925848002979325066164966376483155872594786291361268349330657388`
-   **Max Gas Limit**: 2,500,000
-   **Min Confirmations**: 0
-   **Max Confirmations**: 200
-   **Max Random Values**: 500

## Testing the Deployment

### Step 1: Create a Raffle

```solidity
// Call createRaffle function
raffle.createRaffle(
    "Test Raffle",
    block.timestamp + 1 days,
    100, // max tickets
    true, // allow multiple tickets
    0.1 ether, // ticket price
    address(0) // ETH payment
);
```

### Step 2: Deposit Prize

```solidity
// Deposit ETH prize
raffle.depositPrizeETH{value: 1 ether}(raffleId);
```

### Step 3: Buy Tickets

```solidity
// Buy tickets
raffle.buyTicket{value: 0.1 ether}(raffleId, 1);
```

### Step 4: Request Random Winner

```solidity
// Wait for raffle to end, then request random winner
raffle.requestRandomWinner(raffleId);
```

### Step 5: Finalize Raffle

```solidity
// After winner is selected, finalize the raffle
raffle.finalizeRaffle(raffleId);
```

## Important Notes

1. **Subscription Funding**: Make sure your VRF subscription has enough LINK tokens to fulfill requests
2. **Gas Limits**: The callback gas limit (200,000) should be sufficient for most operations
3. **Confirmations**: Using 3 confirmations provides good security while keeping costs reasonable
4. **Testing**: Always test on Base Sepolia before deploying to mainnet

## Troubleshooting

### Common Issues:

1. **"Invalid subscription"**: Make sure the subscription ID is correct
2. **"Consumer not authorized"**: Add your contract as a consumer to the VRF subscription
3. **"Insufficient funds"**: Ensure the contract has enough ETH to pay for VRF requests (60% premium)
4. **"Request already pending"**: Wait for the previous request to be fulfilled

### Useful Commands:

```bash
# Check contract balance
cast call <CONTRACT_ADDRESS> "getContractBalance()" --rpc-url $BASE_SEPOLIA_RPC_URL

# Check VRF configuration
cast call <CONTRACT_ADDRESS> "getVRFConfiguration()" --rpc-url $BASE_SEPOLIA_RPC_URL

# Check raffle data
cast call <CONTRACT_ADDRESS> "getRaffleData(uint256)" <RAFFLE_ID> --rpc-url $BASE_SEPOLIA_RPC_URL
```

## Security Considerations

1. **Access Control**: Only the platform owner can request random winners
2. **VRF Security**: Chainlink VRF provides cryptographically secure randomness
3. **Escrow System**: Prizes are held in escrow until raffle completion
4. **Service Charges**: Platform collects 5% service charge on winnings

## Next Steps

1. Deploy to Base Sepolia testnet
2. Test all functionality thoroughly
3. Create VRF subscription and add contract as consumer
4. Test random winner selection
5. Deploy to Base mainnet when ready

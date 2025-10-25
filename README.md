# Tikka - Decentralized Raffle Platform

![Tikka Logo](https://via.placeholder.com/200x100/4F46E5/FFFFFF?text=TIKKA)

## 🎯 What is Tikka?

Tikka is a decentralized raffle platform built on Base Sepolia that enables users to create, participate in, and manage transparent raffles with verifiable randomness. The platform supports multiple token types for ticket purchases and prizes, including ETH, ERC20 tokens, and ERC721 NFTs.

## 🚀 Key Features

### **🎲 Verifiable Randomness**

-   Powered by Chainlink VRF v2.5 for cryptographically secure randomness
-   Native ETH payments for VRF requests (no LINK tokens required)
-   Transparent and tamper-proof winner selection

### **💰 Multi-Token Support**

-   **Ticket Purchases**: ETH or any ERC20 token
-   **Prizes**: ETH, ERC20 tokens, or ERC721 NFTs
-   **Flexible Pricing**: Set custom ticket prices in any supported token

### **🔒 Secure Escrow System**

-   Prizes are held in smart contract escrow until raffle completion
-   Automatic prize distribution to winners
-   Platform service charge (5%) for sustainability

### **📊 Comprehensive Analytics**

-   Real-time raffle statistics
-   User participation tracking
-   Platform-wide analytics and reporting

## 🏗️ How Tikka Works

### **1. Raffle Creation**

```
Creator → Deploy Prize → Create Raffle → Set Parameters
```

-   Raffle creators specify:
    -   Description and end time
    -   Maximum ticket count
    -   Ticket price and payment token
    -   Whether multiple tickets per person are allowed

### **2. Prize Escrow**

```
Creator → Transfer Prize → Contract Escrow → Hold Until Completion
```

-   Prizes are transferred to the smart contract
-   Contract holds prizes in escrow until raffle ends
-   Supports ETH, ERC20 tokens, and ERC721 NFTs

### **3. Ticket Sales**

```
Participants → Buy Tickets → Contract Validation → Ticket Issuance
```

-   Users purchase tickets with specified payment tokens
-   Contract validates payment and issues unique tickets
-   Real-time ticket count tracking

### **4. Winner Selection**

```
Raffle Ends → Request Randomness → Chainlink VRF → Select Winner
```

-   Platform owner requests random winner selection
-   Chainlink VRF provides verifiable randomness
-   Winner is selected from all sold tickets

### **5. Prize Distribution**

```
Winner Selected → Finalize Raffle → Transfer Prize → Service Charge
```

-   Winners can withdraw their prizes
-   Platform collects 5% service charge
-   Automatic prize distribution

## 🔧 Technical Architecture

### **Smart Contract Stack**

-   **Solidity**: ^0.8.13
-   **Foundry**: Development and testing framework
-   **Chainlink VRF v2.5**: Verifiable randomness
-   **Base Sepolia**: Testnet deployment

### **Core Contracts**

#### **Raffle.sol** - Main Contract

```solidity
contract Raffle is VRFConsumerBaseV2Plus {
    // VRF Integration
    uint256 public s_subscriptionId;
    bytes32 public s_keyHash;

    // Raffle Management
    mapping(uint256 => RaffleData) public raffles;
    mapping(uint256 => PrizeData) public prizes;
    mapping(uint256 => Ticket) public tickets;

    // Key Functions
    function createRaffle(...) external;
    function buyTicket(...) external payable;
    function requestRandomWinner(...) external;
    function finalizeRaffle(...) external;
}
```

#### **Data Structures**

```solidity
struct RaffleData {
    uint256 id;
    address creator;
    string description;
    uint256 endTime;
    uint256 maxTickets;
    bool allowMultipleTickets;
    uint256 ticketPrice;
    address ticketToken;
    bool isActive;
    address winner;
    uint256 winningTicketId;
    bool winningsWithdrawn;
    bool isFinalized;
}

struct PrizeData {
    address token;
    uint256 tokenId;
    uint256 amount;
    bool isNFT;
    bool isDeposited;
}
```

### **VRF Integration**

-   **Subscription Method**: Uses Chainlink VRF subscription
-   **Native Payments**: ETH payments for VRF requests
-   **Request-Response Pattern**: Asynchronous randomness generation
-   **Callback Security**: Only VRF coordinator can fulfill requests

### **Security Features**

-   **Access Control**: Platform owner and raffle creator permissions
-   **State Validation**: Comprehensive input validation
-   **Reentrancy Protection**: Safe external calls
-   **Overflow Protection**: SafeMath operations

## 🌐 Deployed Contracts

### **Base Sepolia (Latest)**

-   **Contract Address**: [`0x60fd4f42B818b173d7252859963c7131Ed68CA6D`](https://sepolia.basescan.org/address/0x60fd4f42B818b173d7252859963c7131Ed68CA6D)
-   **Deployer**: `0xF18ca72961b486318551B827F6A7124cF1caDf81`
-   **Transaction Hash**: `0x4f6735f049ca6025af24dad02385a4ddfdcb702f02f5eea7e4a53be6ecfd599b`
-   **Status**: ✅ Verified
-   **Features**:
    -   ✅ Large subscription ID support (uint256)
    -   ✅ Native ETH payments for VRF
    -   ✅ `receive()` function for ETH transfers
    -   ✅ Multi-token support (ETH, ERC20, ERC721)

### **Previous Deployments**

-   **Contract Address**: [`0x69A2F4DeC343B06956738376f07dca1787B342C5`](https://sepolia.basescan.org/address/0x69A2F4DeC343B06956738376f07dca1787B342C5)
-   **Contract Address**: [`0xed32402c968d04D1d7F6B3DEfcB7A91321736156`](https://sepolia.basescan.org/address/0xed32402c968d04D1d7F6B3DEfcB7A91321736156)

## 🚀 Getting Started

### **Prerequisites**

-   Base Sepolia ETH for gas fees
-   Base Sepolia ETH for VRF request payments
-   Chainlink VRF subscription (optional for testing)

### **Creating Your First Raffle**

1. **Fund the Contract**

    ```bash
    cast send 0x60fd4f42B818b173d7252859963c7131Ed68CA6D \
        --value 0.01ether \
        --rpc-url https://base-sepolia.infura.io/v3/YOUR_KEY
    ```

2. **Create a Raffle**

    ```solidity
    raffle.createRaffle(
        "My First Raffle",           // description
        block.timestamp + 1 days,    // end time
        100,                         // max tickets
        true,                        // allow multiple tickets
        0.1 ether,                   // ticket price
        address(0)                   // ETH payment
    );
    ```

3. **Deposit Prize**

    ```solidity
    raffle.depositPrizeETH{value: 1 ether}(raffleId);
    ```

4. **Buy Tickets**
    ```solidity
    raffle.buyTicket{value: 0.1 ether}(raffleId, 1);
    ```

### **Testing the Platform**

1. **Create Test Raffles**
2. **Buy Multiple Tickets**
3. **Test Different Token Types**
4. **Verify Winner Selection**
5. **Test Prize Withdrawal**

## 📊 Platform Statistics

### **Current Metrics**

-   **Total Raffles**: Track via `getTotalRaffles()`
-   **Active Raffles**: Monitor via `getActiveRaffleIds()`
-   **Platform Revenue**: 5% service charge on winnings
-   **VRF Requests**: Transparent randomness generation

### **Analytics Functions**

```solidity
// Get platform statistics
function getPlatformStatistics() external view returns (
    uint256 totalRaffles,
    uint256 activeRaffles,
    uint256 endedRaffles,
    uint256 totalTicketsSold,
    uint256 totalWinningsDistributed
);

// Get user participation
function getUserRaffleParticipation(address user) external view returns (
    uint256[] memory raffleIds,
    uint256[] memory ticketCounts,
    uint256[] memory winnings
);
```

## 🔒 Security Considerations

### **Smart Contract Security**

-   **Audited Code**: Comprehensive test coverage
-   **Access Controls**: Role-based permissions
-   **Input Validation**: All parameters validated
-   **State Management**: Proper state transitions

### **VRF Security**

-   **Cryptographic Randomness**: Chainlink VRF v2.5
-   **Subscription Security**: Authorized consumer access
-   **Request Validation**: Proper request/response handling

### **Economic Security**

-   **Escrow System**: Prizes held until completion
-   **Service Charges**: Sustainable platform economics
-   **Gas Optimization**: Efficient contract operations

## 🛠️ Development

### **Local Development**

```bash
# Clone repository
git clone https://github.com/your-org/tikka-contracts.git
cd tikka-contracts

# Install dependencies
forge install

# Run tests
forge test

# Deploy locally
forge script script/DeployRaffle.s.sol --fork-url $BASE_SEPOLIA_RPC_URL
```

### **Testing**

```bash
# Run all tests
forge test

# Run specific test
forge test --match-test testCreateRaffle

# Run with gas reporting
forge test --gas-report
```

## 📚 Documentation

-   **[RAFFLE_README.md](./RAFFLE_README.md)** - Detailed contract documentation
-   **[DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md)** - Deployment instructions
-   **[Base Sepolia Explorer](https://sepolia.basescan.org/address/0x60fd4f42B818b173d7252859963c7131Ed68CA6D)** - Contract verification

## 🤝 Contributing

We welcome contributions! Please see our contributing guidelines and code of conduct.

### **Areas for Contribution**

-   Additional token standards (ERC1155)
-   Enhanced analytics and reporting
-   Mobile application development
-   Frontend interface development
-   Security audits and improvements

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

-   **Documentation**: Check our comprehensive guides
-   **Issues**: Report bugs and feature requests
-   **Community**: Join our Discord for discussions
-   **Security**: Report security issues responsibly

## 🔗 Links

-   **Contract**: [Base Sepolia Explorer](https://sepolia.basescan.org/address/0x60fd4f42B818b173d7252859963c7131Ed68CA6D)
-   **Chainlink VRF**: [VRF Subscription Manager](https://vrf.chain.link/base-sepolia)
-   **Base Sepolia**: [Base Sepolia Faucet](https://bridge.base.org/deposit)
-   **Foundry**: [Foundry Documentation](https://book.getfoundry.sh/)

---

**Built with ❤️ on Base Sepolia using Chainlink VRF**

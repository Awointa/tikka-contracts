// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/Raffle.sol";

contract DeployRaffle is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // VRF parameters for Base Sepolia
        address vrfCoordinator = 0x5C210eF41CD1a72de73bF76eC39637bB0d3d7BEE; // Base Sepolia VRF Coordinator
        // Note: Your subscription ID is too large for uint64. 
        // You may need to create a new subscription or check the correct ID format.
        // For now, using a placeholder - update with correct subscription ID
        uint64 subscriptionId = 1; // Replace with your actual subscription ID
        bytes32 keyHash = 0x9e1344a1247c8a1785d0a4681a27152bffdb43666ae5bf7d14d24a5efd44bf71; // 30 gwei Key Hash
        uint32 callbackGasLimit = 200000; // Within the 2,500,000 max gas limit
        uint16 requestConfirmations = 3; // Within the 0-200 range
        
        Raffle raffle = new Raffle(
            vrfCoordinator,
            subscriptionId,
            keyHash,
            callbackGasLimit,
            requestConfirmations
        );

        console.log("Raffle contract deployed at:", address(raffle));
        console.log("Platform owner:", raffle.platformOwner());
        console.log("Platform service charge:", raffle.getPlatformServiceCharge(), "%");

        vm.stopBroadcast();
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/Raffle.sol";

contract DeployRaffle is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        Raffle raffle = new Raffle();

        console.log("Raffle contract deployed at:", address(raffle));
        console.log("Platform owner:", raffle.platformOwner());
        console.log("Platform service charge:", raffle.getPlatformServiceCharge(), "%");

        vm.stopBroadcast();
    }
}

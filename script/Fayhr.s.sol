// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import "../src/Fayhr.sol";

contract DeployFayhr is Script {
    function run() external {
        
        // Start broadcasting transactions
        vm.startBroadcast();

        // Replace these with your admin and token addresses
        address _admin = 0x25d8D7bFf4D6C7af503B5EdE7d4503bD9AD66D6b;
        address _tokenAddress = 0x9bBA86Fc3d058855c570C7BFc0beFa2EC91F98c7;
        address _feecollector =  0x617eca02EE345f7dB08A941f22cef7b284484e2e;
        uint256 _consensusPeriod = 604800;
        

        // Deploy the contract
        Fayhr fayhr = new Fayhr(_admin, _consensusPeriod, _tokenAddress, _feecollector);

        // Log the deployed contract address
        console.log("Fayhr deployed at:", address(fayhr));

        // Stop broadcasting transactions
        vm.stopBroadcast();
    }
}

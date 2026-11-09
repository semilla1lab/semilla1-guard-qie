// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {Semilla1GuardFactory} from "../src/Semilla1GuardFactory.sol";

/// Usage (QIE mainnet, chainId 1990) -- only once the deployer has QIE gas:
///   forge script script/Deploy.s.sol --rpc-url $QIE_RPC --private-key $PK --broadcast --legacy
contract Deploy is Script {
    function run() external returns (Semilla1GuardFactory f) {
        vm.startBroadcast();
        f = new Semilla1GuardFactory();
        vm.stopBroadcast();
        console.log("Semilla1GuardFactory", address(f));
    }
}

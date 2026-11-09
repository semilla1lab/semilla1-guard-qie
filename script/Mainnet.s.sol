// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {Semilla1GuardFactory} from "../src/Semilla1GuardFactory.sol";
import {Semilla1Guard} from "../src/Semilla1Guard.sol";

/// QIE mainnet (chain 1990): deploy the factory and run one live demo with near-zero value.
/// The deployer is owner, agent and allow-listed receiver, so the single ALLOW payment
/// (1e12 wei) comes back to the same wallet and the guard ends empty. Two DENY attempts
/// (unknown receiver, over per-tx cap) move nothing but are logged as Decision events.
/// Env: OWNER_PK (never commit).
///   forge script script/Mainnet.s.sol --rpc-url https://rpc5mainnet.qie.digital --legacy --slow --broadcast
contract Mainnet is Script {
    function run() external {
        uint256 pk = vm.envUint("OWNER_PK");
        address payable me = payable(vm.addr(pk));
        address payable stranger = payable(address(0x1234));

        vm.startBroadcast(pk);
        Semilla1GuardFactory f = new Semilla1GuardFactory();
        Semilla1Guard g = Semilla1Guard(payable(f.createGuard{value: 1e12}(me, 1e12, 3e12, 0)));
        g.setAllowed(me, true);
        g.agentSpend(me, 1e12, "mainnet demo: allowed payment");        // ALLOW (returns to owner)
        g.agentSpend(stranger, 1e12, "mainnet demo: unknown receiver"); // DENY NOT_ALLOWED
        g.agentSpend(me, 2e12, "mainnet demo: over per-tx cap");        // DENY OVER_TX_CAP
        vm.stopBroadcast();

        console.log("factory", address(f));
        console.log("guard", address(g));
        console.log("attempts", g.attempts());
        console.log("spentInWindow", g.spentInWindow());
        console.log("guardBalance", address(g).balance);
        console.log("totalGuards", f.totalGuards());
    }
}

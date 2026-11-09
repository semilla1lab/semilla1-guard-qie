// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {Semilla1GuardFactory} from "../src/Semilla1GuardFactory.sol";
import {Semilla1Guard} from "../src/Semilla1Guard.sol";

/// Judge demo: creates a guard via the factory, funds it, allow-lists one receiver, then the
/// agent tries 3 spends -> 1 ALLOW + 2 DENY (not allow-listed, over per-tx cap). All decisions
/// are Decision events on-chain.
/// Env: FACTORY, OWNER_PK, AGENT_PK, RECEIVER, STRANGER. Amounts are tiny (wei-scale).
///   forge script script/Demo.s.sol --rpc-url $RPC --broadcast --legacy
contract Demo is Script {
    function run() external {
        Semilla1GuardFactory f = Semilla1GuardFactory(vm.envAddress("FACTORY"));
        uint256 ownerPk = vm.envUint("OWNER_PK");
        uint256 agentPk = vm.envUint("AGENT_PK");
        address agent = vm.addr(agentPk);
        address payable receiver = payable(vm.envAddress("RECEIVER"));
        address payable stranger = payable(vm.envAddress("STRANGER"));

        uint256 perTx = 1e12; uint256 daily = 3e12; uint256 cool = 0;

        vm.startBroadcast(ownerPk);
        Semilla1Guard g = Semilla1Guard(payable(f.createGuard{value: 5e12}(agent, perTx, daily, cool)));
        g.setAllowed(receiver, true);
        if (agent.balance < 1e15) payable(agent).transfer(1e15); // agent gas (tiny)
        vm.stopBroadcast();

        vm.startBroadcast(agentPk);
        g.agentSpend(receiver, 1e12, "demo: allowed payment");      // ALLOW
        g.agentSpend(stranger, 1e12, "demo: unknown receiver");     // DENY NOT_ALLOWED
        g.agentSpend(receiver, 2e12, "demo: over per-tx cap");      // DENY OVER_TX_CAP
        vm.stopBroadcast();

        console.log("guard", address(g));
        console.log("attempts", g.attempts());
        console.log("spentInWindow", g.spentInWindow());
        console.log("totalGuards", f.totalGuards());
    }
}

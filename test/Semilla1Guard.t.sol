// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {Test} from "forge-std/Test.sol";
import {Semilla1Guard} from "../src/Semilla1Guard.sol";

contract Semilla1GuardTest is Test {
    Semilla1Guard g;
    address owner = address(0xA11CE);
    address agent = address(0xA6E);
    address payable shop = payable(address(0x5409));
    address payable evil = payable(address(0xBAD));

    function setUp() public {
        vm.warp(1_000_000);
        g = new Semilla1Guard{value: 10 ether}(owner, agent, 1 ether, 2 ether, 60);
        vm.prank(owner); g.setAllowed(shop, true);
    }

    function testAllowWithinPolicy() public {
        vm.prank(agent); assertTrue(g.agentSpend(shop, 0.5 ether, "ok"));
        assertEq(shop.balance, 0.5 ether);
    }
    function testDenyNotAllowListed() public {
        vm.prank(agent); assertFalse(g.agentSpend(evil, 0.1 ether, "x"));
        assertEq(evil.balance, 0);
    }
    function testDenyOverTxCap() public {
        vm.prank(agent); assertFalse(g.agentSpend(shop, 1.5 ether, "x"));
    }
    function testDenyCooldown() public {
        vm.startPrank(agent);
        assertTrue(g.agentSpend(shop, 0.5 ether, "a"));
        assertFalse(g.agentSpend(shop, 0.5 ether, "b"));
        vm.warp(block.timestamp + 61);
        assertTrue(g.agentSpend(shop, 0.5 ether, "c"));
    }
    function testDailyCapAndReset() public {
        vm.startPrank(agent);
        assertTrue(g.agentSpend(shop, 1 ether, "a")); vm.warp(block.timestamp + 61);
        assertTrue(g.agentSpend(shop, 1 ether, "b")); vm.warp(block.timestamp + 61);
        assertFalse(g.agentSpend(shop, 0.1 ether, "over"));
        vm.warp(block.timestamp + 1 days);
        assertTrue(g.agentSpend(shop, 1 ether, "next day"));
    }
    function testPause() public {
        vm.prank(owner); g.setPaused(true);
        vm.prank(agent); assertFalse(g.agentSpend(shop, 0.1 ether, "x"));
    }
    function testOnlyAgentCanSpend() public {
        vm.prank(evil); vm.expectRevert(Semilla1Guard.NotAgent.selector);
        g.agentSpend(shop, 0.1 ether, "x");
    }
    function testOnlyOwnerAdmin() public {
        vm.prank(agent); vm.expectRevert(Semilla1Guard.NotOwner.selector);
        g.setAllowed(evil, true);
        vm.prank(agent); vm.expectRevert(Semilla1Guard.NotOwner.selector);
        g.withdraw(evil, 1 ether);
    }
    /// Compromised agent key: worst case loss bounded by dailyCap per day.
    function testFuzzCompromisedAgentBounded(uint96[8] memory amts) public {
        vm.startPrank(agent);
        for (uint i; i < amts.length; i++) {
            g.agentSpend(shop, amts[i], "fuzz");
            g.agentSpend(evil, amts[i], "fuzz");
            vm.warp(block.timestamp + 61);
        }
        assertLe(shop.balance, 2 ether);
        assertEq(evil.balance, 0);
    }
}

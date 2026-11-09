// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {Semilla1Guard} from "../src/Semilla1Guard.sol";
import {Semilla1GuardFactory} from "../src/Semilla1GuardFactory.sol";

contract FactoryTest is Test {
    Semilla1GuardFactory f;
    address alice = address(0xA11CE);
    address agent = address(0xA6E7);

    function setUp() public { f = new Semilla1GuardFactory(); vm.deal(alice, 10 ether); }

    function testCreateSetsOwnerAndFunds() public {
        vm.prank(alice);
        address g = f.createGuard{value: 1 ether}(agent, 0.1 ether, 0.5 ether, 0);
        assertEq(Semilla1Guard(payable(g)).owner(), alice);
        assertEq(Semilla1Guard(payable(g)).agent(), agent);
        assertEq(g.balance, 1 ether);
        assertEq(f.totalGuards(), 1);
        assertEq(f.guardsCountOf(alice), 1);
    }

    function testRegistryCountsMany() public {
        for (uint256 i; i < 5; i++) { vm.prank(alice); f.createGuard(agent, 1, 2, 0); }
        assertEq(f.totalGuards(), 5);
    }
}

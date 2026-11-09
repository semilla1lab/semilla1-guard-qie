// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Semilla1Guard} from "./Semilla1Guard.sol";

/// @title Semilla1GuardFactory
/// @notice Anyone can deploy their own spending guard for an AI agent. The caller becomes owner.
///         Keeps an on-chain registry so adoption (traction) is verifiable by judges.
contract Semilla1GuardFactory {
    address[] public guards;
    mapping(address => address[]) public guardsOf;

    event GuardCreated(address indexed owner, address indexed agent, address guard, uint256 perTxCap, uint256 dailyCap, uint256 cooldown);

    function createGuard(address agent, uint256 perTxCap, uint256 dailyCap, uint256 cooldown) external payable returns (address g) {
        g = address(new Semilla1Guard{value: msg.value}(msg.sender, agent, perTxCap, dailyCap, cooldown));
        guards.push(g);
        guardsOf[msg.sender].push(g);
        emit GuardCreated(msg.sender, agent, g, perTxCap, dailyCap, cooldown);
    }

    function totalGuards() external view returns (uint256) { return guards.length; }
    function guardsCountOf(address owner) external view returns (uint256) { return guardsOf[owner].length; }
}

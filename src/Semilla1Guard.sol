// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title Semilla1 Guard (QIE port)
/// @notice Spending-limit vault for AI agents. The owner funds the vault and sets policy;
/// the agent key can only move native coin through agentSpend, within on-chain caps:
/// per-tx cap, rolling 24h cap, receiver allow-list and cooldown. Every attempt
/// (allowed or denied) is emitted as an event, so the audit trail is on-chain.
/// Worst case if the agent key is compromised: loss bounded by dailyCap.
contract Semilla1Guard {
    address public immutable owner;
    address public agent;
    bool public paused;

    uint256 public perTxCap;
    uint256 public dailyCap;
    uint256 public cooldown; // seconds between spends

    uint256 public windowStart;
    uint256 public spentInWindow;
    uint256 public lastSpend;
    uint256 public attempts;

    mapping(address => bool) public allowed;

    enum Reason { OK, PAUSED, NOT_ALLOWED, OVER_TX_CAP, OVER_DAILY_CAP, COOLDOWN, NO_FUNDS, TRANSFER_FAILED }

    event Decision(uint256 indexed id, address indexed receiver, uint256 amount, bool allowed, Reason reason, string memo);
    event PolicySet(uint256 perTxCap, uint256 dailyCap, uint256 cooldown);
    event AllowListSet(address indexed receiver, bool allowed);
    event AgentSet(address indexed agent);
    event Paused(bool paused);
    event Funded(address indexed from, uint256 amount);
    event Withdrawn(address indexed to, uint256 amount);

    error NotOwner();
    error NotAgent();

    modifier onlyOwner() { if (msg.sender != owner) revert NotOwner(); _; }

    constructor(address _owner, address _agent, uint256 _perTxCap, uint256 _dailyCap, uint256 _cooldown) payable {
        owner = _owner;
        agent = _agent;
        perTxCap = _perTxCap;
        dailyCap = _dailyCap;
        cooldown = _cooldown;
        windowStart = block.timestamp;
        emit AgentSet(_agent);
        emit PolicySet(_perTxCap, _dailyCap, _cooldown);
        if (msg.value > 0) emit Funded(msg.sender, msg.value);
    }

    receive() external payable { emit Funded(msg.sender, msg.value); }

    // ---- owner ----
    function setPolicy(uint256 _perTxCap, uint256 _dailyCap, uint256 _cooldown) external onlyOwner {
        perTxCap = _perTxCap; dailyCap = _dailyCap; cooldown = _cooldown;
        emit PolicySet(_perTxCap, _dailyCap, _cooldown);
    }
    function setAllowed(address receiver, bool ok) external onlyOwner {
        allowed[receiver] = ok;
        emit AllowListSet(receiver, ok);
    }
    function setAgent(address _agent) external onlyOwner { agent = _agent; emit AgentSet(_agent); }
    function setPaused(bool p) external onlyOwner { paused = p; emit Paused(p); }
    function withdraw(address payable to, uint256 amount) external onlyOwner {
        (bool ok,) = to.call{value: amount}("");
        require(ok, "withdraw failed");
        emit Withdrawn(to, amount);
    }

    // ---- views ----
    function remainingToday() public view returns (uint256) {
        if (block.timestamp >= windowStart + 1 days) return dailyCap;
        return spentInWindow >= dailyCap ? 0 : dailyCap - spentInWindow;
    }

    function check(address receiver, uint256 amount) public view returns (Reason) {
        if (paused) return Reason.PAUSED;
        if (!allowed[receiver]) return Reason.NOT_ALLOWED;
        if (amount > perTxCap) return Reason.OVER_TX_CAP;
        if (amount > remainingToday()) return Reason.OVER_DAILY_CAP;
        if (lastSpend != 0 && block.timestamp < lastSpend + cooldown) return Reason.COOLDOWN;
        if (amount > address(this).balance) return Reason.NO_FUNDS;
        return Reason.OK;
    }

    // ---- agent ----
    /// @return ok true if paid. A denial does NOT revert, so the DENY decision is logged on-chain.
    function agentSpend(address payable receiver, uint256 amount, string calldata memo) external returns (bool ok) {
        if (msg.sender != agent) revert NotAgent();
        uint256 id = ++attempts;
        Reason r = check(receiver, amount);
        if (r != Reason.OK) { emit Decision(id, receiver, amount, false, r, memo); return false; }

        if (block.timestamp >= windowStart + 1 days) { windowStart = block.timestamp; spentInWindow = 0; }
        spentInWindow += amount;
        lastSpend = block.timestamp;
        (bool sent,) = receiver.call{value: amount, gas: 10000}("");
        if (!sent) {
            spentInWindow -= amount;
            emit Decision(id, receiver, amount, false, Reason.TRANSFER_FAILED, memo);
            return false;
        }
        emit Decision(id, receiver, amount, true, Reason.OK, memo);
        return true;
    }
}

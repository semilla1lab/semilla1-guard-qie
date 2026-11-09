# Semilla1 Guard for QIE

On-chain spending guard for autonomous AI agents on QIE (EVM). An owner funds a guard and lets an agent key spend from it, but only inside hard rules enforced by the contract:

- max amount per transaction
- max amount per rolling 24 h window
- allow-list of destinations
- cooldown between payments
- owner pause switch

Every attempt, allowed or denied, is emitted as a `Decision` event, so the agent's behaviour is auditable on-chain. A compromised agent key cannot exceed the daily cap or pay an unlisted address (covered by fuzz tests).

`Semilla1GuardFactory` lets anyone create their own guard (caller becomes owner) and keeps an on-chain registry (total guards and guards per owner) to measure adoption.

Track: AI + Autonomous Agents. Built by Semilla1 Lab. Port of Semilla1 Guard for NEAR.

## Build and test

```sh
forge install foundry-rs/forge-std --no-git   # if lib/ is empty
forge test -vv
```

11 tests (9 guard incl. 256-run fuzz, 2 factory), all passing.

## Live on QIE mainnet (chain 1990)

Explorer: https://mainnet.qie.digital (factory and guard source verified)

Live demo (read-only, mainnet data): https://semilla1-guard-qie.netlify.app

- Factory: `0x24f0E4d15aA3d06557e96d31fED64F8181b24aF2` (deploy tx [`0x6fec6d70…2909`](https://mainnet.qie.digital/tx/0x6fec6d702c3e230a0e0c56953ba577d5d388150f244e866a7e870e728c632909))
- Demo guard: `0x390Ee8c02076737C632a6BBA069Aaf1f82C29cc4`, 3 attempts: 1 ALLOW, 2 DENY (NOT_ALLOWED, OVER_TX_CAP)
- Demo txs: `0x534484d690fef99375c966ebb09a26dca93639cece2ccd8bcce68b9931d1518c` (createGuard), `0xc9b80babf28f2e55047c33c0fea92cf881120a8ef6d8f2120dc4908490196726` (allow-list), `0x235868ff246f001ae1a14c97fe034ae2320892fb8d174562e713c20049f7cf69` (ALLOW), `0x26f8a0b1f570246dbc3252b6b16700bfddb24bf43e24d12f621b41171564812f` (DENY NOT_ALLOWED), `0x76c986635479e7fe3468c363d55b228a8fff61aae9799e68315002d31c76e76f` (DENY OVER_TX_CAP)
- Measured gas on mainnet: 2,183,812 total (deploy 1,049,224) = 0.00246 QIE at 1.125 gwei.
- Reproduce: `OWNER_PK=... forge script script/Mainnet.s.sol --rpc-url https://rpc5mainnet.qie.digital --legacy --slow --broadcast`

## Earlier rehearsal on QIE testnet (chain 1983)

- Factory: `0x24f0E4d15aA3d06557e96d31fED64F8181b24aF2` (deploy tx `0xab22ea625ccb8906a09f8315e6d6baf74446a0873e1ac9c192ae337bcc5df357`)
- Demo guard: `0x390Ee8c02076737C632a6BBA069Aaf1f82C29cc4`, 3 attempts: 1 ALLOW, 2 DENY
- Demo txs: `0x4278241193066c6f9d76b2239b7bc7b80b28ad065da8107c26f6c0be3acc8d76`, `0x03266cba9e42dd396d07507155c1fa7e9fc31c8c0738dd1b736a278af7903fdc`, `0xc7cd5b061fc3723eeca6e8fa2294580bd99a333858cbbe0d5e4195617fa76218`, `0xac5dafe2d6b26bb3bc2a71db120dad4b7cd9580425557376480c68ed875ecae3`, `0x9fa697824479fd7f3b01fa1aa33bbaa79d31a72c6e9576e10baa744a64741e6b`, `0xe34ce268ebfe0e2fbd1ef52bed0882d8a31d1052415db10bd3866cc11c5e8bc8`


## Reproduce the demo

```sh
export OWNER_PK=... AGENT_PK=...   # never commit keys
forge script script/Deploy.s.sol --rpc-url https://rpc5testnet.qie.digital --broadcast
forge script script/Demo.s.sol   --rpc-url https://rpc5testnet.qie.digital --broadcast
```

Measured gas: deploy 1,049,516 + demo 1,158,248.

## License

MIT

## Agent integration (AI + Agents track)
`agent/guard_pay.sh` is a one-call-one-JSON tool wrapper an AI agent can use; `agent/tools.json` is the matching function-calling schema (`guard_check`, `guard_pay`). The agent never holds the funds: it can only ask the guard to pay, and the owner's policy decides.

```bash
export GUARD=0x390Ee8c02076737C632a6BBA069Aaf1f82C29cc4   # mainnet 1990 demo guard (same address on testnet 1983)
agent/guard_pay.sh check 0x000000000000000000000000000000000000dEaD 1000
# {"mode":"check","would_allow":true,"reason":"OK","remaining_today_wei":"2000000000000"}
agent/guard_pay.sh check 0x1111111111111111111111111111111111111111 1000
# {"mode":"check","would_allow":false,"reason":"NOT_ALLOWED",...}
agent/guard_pay.sh check 0x000000000000000000000000000000000000dEaD 2000000000000
# {"mode":"check","would_allow":false,"reason":"OVER_TX_CAP",...}
AGENT_PK=... agent/guard_pay.sh pay <receiver> <amount_wei> "memo"   # sends agentSpend; DENY is logged on-chain
```
`check` is read-only (no gas). `pay` always submits so that denied attempts leave a `Decision` event as an audit trail; set `SKIP_ON_DENY=1` to skip the tx when the precheck already denies.

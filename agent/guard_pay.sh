#!/usr/bin/env bash
# Semilla1 Guard — agent tool wrapper (one call = one JSON line on stdout).
# Intended as a function-calling tool for an AI agent: the agent never holds the
# funds; it can only ASK the guard to pay. The guard enforces the owner's policy.
#
# Usage:
#   guard_pay.sh check <receiver> <amount_wei>            # read-only, no gas
#   guard_pay.sh pay   <receiver> <amount_wei> "<memo>"   # needs AGENT_PK env
# Env: GUARD (guard address, required), RPC (default QIE mainnet rpc5), AGENT_PK (pay only)
set -euo pipefail
RPC="${RPC:-https://rpc5mainnet.qie.digital}"
: "${GUARD:?set GUARD=<guard address>}"
REASONS=(OK PAUSED NOT_ALLOWED OVER_TX_CAP OVER_DAILY_CAP COOLDOWN NO_FUNDS TRANSFER_FAILED)
mode="${1:-}"; recv="${2:-}"; amt="${3:-}"; memo="${4:-}"
[[ "$mode" =~ ^(check|pay)$ && "$recv" =~ ^0x[0-9a-fA-F]{40}$ && "$amt" =~ ^[0-9]+$ ]] || {
  echo '{"error":"usage: check|pay <0xreceiver> <amount_wei> [memo]"}'; exit 2; }

r=$(cast call --rpc-url "$RPC" "$GUARD" "check(address,uint256)(uint8)" "$recv" "$amt")
reason="${REASONS[$r]:-UNKNOWN}"
left=$(cast call --rpc-url "$RPC" "$GUARD" "remainingToday()(uint256)" | awk '{print $1}')

if [[ "$mode" == check ]]; then
  printf '{"mode":"check","would_allow":%s,"reason":"%s","remaining_today_wei":"%s"}\n' \
    "$([[ $reason == OK ]] && echo true || echo false)" "$reason" "$left"
  exit 0
fi

: "${AGENT_PK:?set AGENT_PK for pay mode}"
# Even when check() says DENY we still submit: the denial is logged on-chain as a
# Decision event (audit trail of what the agent tried). Set SKIP_ON_DENY=1 to save gas.
if [[ "$reason" != OK && "${SKIP_ON_DENY:-0}" == 1 ]]; then
  printf '{"mode":"pay","sent":false,"reason":"%s","note":"skipped, precheck denied"}\n' "$reason"; exit 0
fi
out=$(cast send --json --rpc-url "$RPC" --private-key "$AGENT_PK" "$GUARD" \
  "agentSpend(address,uint256,string)" "$recv" "$amt" "$memo")
tx=$(echo "$out" | python3 -c 'import sys,json;print(json.load(sys.stdin)["transactionHash"])')
st=$(echo "$out" | python3 -c 'import sys,json;print(int(json.load(sys.stdin)["status"],16))')
printf '{"mode":"pay","tx":"%s","tx_status":%s,"allowed":%s,"reason":"%s"}\n' \
  "$tx" "$st" "$([[ $reason == OK ]] && echo true || echo false)" "$reason"

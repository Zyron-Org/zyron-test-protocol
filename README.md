# 🛡️ Zyron Vulnerable DeFi Protocol Benchmark (`zyron-test-protocol`)

A curated, multi-file Solidity smart contract repository containing realistic DeFi vulnerabilities designed to test and benchmark the **Zyron Autonomous AI Security Platform & EVM Sandbox Prover**.

---

## 📁 Repository Structure

```
zyron-test-protocol/
├── contracts/
│   ├── VaultCore.sol            # Flagship ETH Yield Vault (Reentrancy, Unprotected Init, Mutex FP)
│   ├── PriceOracleAdapter.sol   # Instant Spot Price Feed (Flash Loan Distortion & Access Bypass)
│   ├── RewardDistributor.sol    # Liquidity Mining Rewards (Unchecked Transfer & Uncapped Mint)
│   └── interfaces/
│       ├── IERC20.sol           # Standard ERC-20 token interface
│       └── IVault.sol           # Core Vault interface
├── test/
│   └── VaultExploit.t.sol       # Foundry cheatcode reproduction test for reentrancy
├── foundry.toml                 # Foundry project configuration (solc 0.8.20)
└── README.md
```

---

## 🎯 Ground Truth Vulnerabilities Benchmark

| File | Line / Function | Severity | Taxonomy | Expected Zyron Verdict | Description |
|---|---|---|---|---|---|
| **`VaultCore.sol`** | `withdraw()` | **CRITICAL** | `SWC-107 · CWE-841` | `PROVEN_EXPLOIT` | **State-change after external call (Reentrancy)**: Ether transfer executes before `sharesOf` deduction, allowing recursive vault drain. |
| **`VaultCore.sol`** | `initialize()` | **HIGH** | `SWC-118 · CWE-284` | Flagged | **Unprotected Initializer**: Lacks `initializer` modifier or lock, allowing anyone to re-initialize governance and oracle parameters. |
| **`VaultCore.sol`** | `safeEmergencyWithdraw()` | **INFORMATIONAL** | `SWC-107` | `PROVEN_FALSE_POSITIVE` | **False Positive Candidate**: Static analysis flags external call, but the autonomous EVM sandbox simulates execution and confirms it reverts safely with `"LOCKED"`. |
| **`PriceOracleAdapter.sol`** | `getAssetPrice()` | **HIGH** | `SWC-101 · CWE-682` | Flagged | **Spot Price / Flash Loan Manipulation**: Calculates price directly from instant balance ratios without TWAP or time window checks. |
| **`PriceOracleAdapter.sol`** | `setPool()` | **HIGH** | `SWC-105 · CWE-284` | Flagged | **Missing Access Control**: Lacks `onlyOwner`, allowing any caller to reassign the oracle pool address. |
| **`RewardDistributor.sol`** | `notifyRewardAmount()` | **HIGH** | `SWC-105 · CWE-284` | Flagged | **Missing Access Control**: Anyone can inject arbitrary reward durations and dilute distribution rates. |
| **`RewardDistributor.sol`** | `claimReward()` | **MEDIUM** | `SWC-104 · CWE-252` | Flagged | **Unchecked Return Value**: Raw `token.transfer()` return value ignored; non-compliant ERC20s (e.g. USDT) will revert or fail silently without `SafeERC20`. |

---

## 🚀 How to Test on Zyron

1. **Intake / New Audit Request**:
   - Go to `http://localhost:3001/portal/new-request`
   - Link this repository: `https://github.com/Zyron-Org/zyron-test-protocol` (branch: `main`)
   - Or paste the contents of `contracts/VaultCore.sol`
2. **Run AST & Autonomous AI Prover**:
   - The platform will run all 14 AST passes and triage with cloud LLMs.
   - The autonomous agent (`zyron-agent`) compiles bytecode and executes simulated attack sequences in the virtual sandbox.
3. **Replay Interactive Traces**:
   - Open `/auditor/review/[id]` or `/portal/track/[id]`.
   - Use the **EVM Trace Stepper** to watch the attacker contract recursively invoke `withdraw()` and drain 100% of the vault liquidity step-by-step.

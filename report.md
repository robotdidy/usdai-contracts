# USDai Contracts Security Review

## Critical Vulnerabilities

### 1. `OUSDaiUtility` Fails to Refund `msg.value` on Failed Cross-Chain Sends

**Severity:** High
**Location:** `src/omnichain/OUSDaiUtility.sol` (`_deposit`, `_depositAndStake`, `_stake`)

**Description:**
In `OUSDaiUtility`, operations that compose cross-chain messages (`ActionType.Deposit`, `DepositAndStake`, and `Stake`) execute `_usdaiOAdapter.send` or `_stakedUsdaiOAdapter.send` wrapped in a `try/catch` block. When the `send` operation reverts (e.g., due to an insufficient `nativeFee` provided by the caller or executor), the `catch` block correctly refunds the principal tokens (`usdai` or `susdai`) to the recipient.

However, the `catch` blocks explicitly transfer the tokens via `IERC20.transfer` rather than invoking the internal `_refund` function. The `_refund` function is responsible for returning any unspent `msg.value` (which includes the `nativeFee` for LayerZero). By not calling `_refund`, the `msg.value` sent by the relayer/executor is permanently trapped within the `OUSDaiUtility` contract. Because `lzCompose` does not revert when the internal operation returns `false`, the cross-chain execution completes successfully from LayerZero's perspective, but the user's `nativeFee` is lost.

**Impact:**
Any native ETH sent to cover LayerZero fees is permanently locked in the contract if the `send` operation fails. There is no mechanism to rescue native ETH from the `OUSDaiUtility` contract, leading to a permanent loss of funds.

**Proof of Concept / Affected Code:**
```solidity
// In _deposit()
} catch (bytes memory reason) {
    /* Transfer the usdai to owner */
    _usdai.transfer(to, usdaiAmount);

    /* Emit the failed action event */
    emit ActionFailed("Send", reason);

    return false; // msg.value is NOT refunded
}
```

---

### 2. `Math.mulDiv` Rounding Down Allows Share-Free Asset Withdrawals

**Severity:** Medium/High
**Location:** `src/RedemptionLogic.sol` (`_withdraw`)

**Description:**
When a user calls `withdraw(amount)` on `StakedUSDai`, the contract uses `RedemptionLogic._withdraw` to pull assets from the user's pending redemption requests. The logic calculates how many shares to deduct from the request (`sharesToRedeem`) based on the requested `amountToWithdraw`.

Because it uses `Math.mulDiv(amountToWithdraw, redemption_.redeemableShares, redemption_.withdrawableAmount)`, the division rounds **down** towards zero. If a user withdraws a small enough `amount`, `sharesToRedeem` rounds down to `0`. The user receives the assets, their `withdrawableAmount` decreases, but their `redeemableShares` remains completely intact.

The user can exploit this by repeatedly calling `withdraw` with an amount just small enough to cause `sharesToRedeem` to truncate to 0. They will fully drain their `withdrawableAmount` without spending any `redeemableShares`. Since `withdrawableAmount` acts as a ceiling, they cannot steal funds belonging to other users, but they do artificially retain their shares within the redemption struct.

**Impact:**
This violates the strict accounting integrity of EIP-4626/EIP-7540, where assets withdrawn must correspond to shares burned or deducted. While the immediate financial impact is contained to the user's own `withdrawableAmount` ceiling, preserving unbacked `redeemableShares` may compromise integrations relying on `claimableRedeemRequest` to assess user equity.

---

### 3. Missing Staleness Checks in Chainlink Oracle

**Severity:** Medium
**Location:** `src/oracles/ChainlinkPriceOracle.sol` (`_getDerivedPrice`)

**Description:**
The `ChainlinkPriceOracle` utilizes `latestRoundData()` to retrieve both the base token price and the PYUSD price. However, the implementation does not validate the `updatedAt` timestamp returned by the oracle.

**Impact:**
If the Chainlink price feed becomes stale or the sequencer goes down, the oracle will continue to return outdated prices. This can lead to significant mispricing during periods of high volatility, allowing users to deposit or redeem assets at favorable, outdated rates.

**Affected Code:**
```solidity
(, int256 tokenPrice,,,) = tokenPriceFeed.latestRoundData();
...
(, int256 pyusdPrice,,,) = _pyusdPriceFeed.latestRoundData();
```

---

## Low / Informational Findings

1. **EIP-7540 Parameter Naming Mismatch:** In `StakedUSDai.sol`, the `redeem` and `withdraw` functions name their third parameter `controller` instead of `owner`. EIP-4626 and EIP-7540 dictate specific parameter names in the ABI for standard compliance. This may break strict integrators.
2. **Missing Sequencer Uptime Feed:** If `ChainlinkPriceOracle` is deployed on L2s (e.g., Arbitrum, Optimism), it must implement a check against the Sequencer Uptime Feed to prevent exploiting stale prices during sequencer downtime.
3. **Underflow risk in `_accrue`:** In `LoanRouterPositionManagerLogic`, if an integration directly calls `loanCollateralLiquidated` without first calling `loanLiquidated`, `loan.liquidationTimestamp` defaults to 0, which will cause an underflow when `timestamp - lastRepaymentTimestamp` is evaluated. This relies heavily on proper lifecycle sequencing from the external `LoanRouter`.

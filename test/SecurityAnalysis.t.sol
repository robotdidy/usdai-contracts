// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import {BaseTest} from "./Base.t.sol";
import {StakedUSDai} from "src/StakedUSDai.sol";
import {IStakedUSDai} from "src/interfaces/IStakedUSDai.sol";
import {RedemptionLogic} from "src/RedemptionLogic.sol";

contract SecurityAnalysisTest is BaseTest {
    function setUp() public override {
        super.setUp();
    }

    // ========================================================================
    // TEST 1: Zero Values
    // ========================================================================
    function test_ZeroDeposit() public {
        vm.startPrank(users.normalUser1);

        vm.expectRevert(); // Expect revert on zero
        stakedUsdai.deposit(0, users.normalUser1);

        vm.stopPrank();
    }

    // ========================================================================
    // TEST 2: Max Values
    // ========================================================================
    function test_MaxDeposit() public {
        vm.startPrank(users.normalUser1);

        uint256 maxVal = type(uint256).max;
        deal(address(usdai), users.normalUser1, maxVal);
        usdai.approve(address(stakedUsdai), maxVal);

        // This should fail due to supply cap or overflow in calculations if not handled
        // or succeed if system is robust.
        // Note: USDai has supply cap.

        // Let's try a very large value that fits in uint256 but might overflow internal calcs
        // 1e50 is > 2^128 but < 2^256
        uint256 largeVal = 1e30;
        deal(address(usdai), users.normalUser1, largeVal);
        usdai.approve(address(stakedUsdai), largeVal);

        try stakedUsdai.deposit(largeVal, users.normalUser1) {
            // Success
        } catch {
            // Fail
        }

        vm.stopPrank();
    }

    // ========================================================================
    // TEST 3: Redemption Queue Logic
    // ========================================================================
    function test_RedemptionQueue_Order() public {
        vm.startPrank(users.normalUser1);
        stakedUsdai.deposit(100 ether, users.normalUser1);
        stakedUsdai.requestRedeem(10 ether, users.normalUser1, users.normalUser1);
        vm.stopPrank();

        vm.startPrank(users.normalUser2);
        stakedUsdai.deposit(100 ether, users.normalUser2);
        stakedUsdai.requestRedeem(20 ether, users.normalUser2, users.normalUser2);
        vm.stopPrank();

        (uint256 index, uint256 head, uint256 tail, uint256 pending, ) = stakedUsdai.redemptionQueueInfo();

        // Head should be User1's request (ID 1)
        // Tail should be User2's request (ID 2)
        assertEq(head, 1, "Head should be 1");
        assertEq(tail, 2, "Tail should be 2");
        assertEq(pending, 30 ether, "Pending should be 30");

        // Verify linked list
        (IStakedUSDai.Redemption memory r1, ) = stakedUsdai.redemption(1);
        (IStakedUSDai.Redemption memory r2, ) = stakedUsdai.redemption(2);

        assertEq(r1.next, 2, "R1 next should be 2");
        assertEq(r2.prev, 1, "R2 prev should be 1");
    }

    // ========================================================================
    // TEST 4: Rounding / Share Price Manipulation (Inflation Attack)
    // ========================================================================
    function test_InflationAttack() public {
        // Setup clean state if possible, or use new deployment
        // But StakedUSDai prevents this with LOCKED_SHARES.
        // Let's verify LOCKED_SHARES logic.

        uint256 totalShares = stakedUsdai.totalShares();
        // Since we are in setUp, checks if shares exist

        if (totalShares == 0) {
            vm.startPrank(users.normalUser1);
            deal(address(usdai), users.normalUser1, 1);
            usdai.approve(address(stakedUsdai), 1);

            // Deposit 1 wei
            stakedUsdai.deposit(1, users.normalUser1);

            // Check if locked shares minted
            // Total shares should be 1 (user) + 1e6 (locked)
            uint256 newTotalShares = stakedUsdai.totalShares();
            assertGt(newTotalShares, 1e6, "Locked shares should be minted");
            vm.stopPrank();
        }
    }
}

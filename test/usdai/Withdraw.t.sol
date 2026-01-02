// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import {BaseTest} from "../Base.t.sol";

import {IUSDai} from "../../src/interfaces/IUSDai.sol";

contract USDaiWithdrawTest is BaseTest {
    function testFuzz__USDaiWithdraw(
        uint256 amount
    ) public {
        vm.assume(amount > 0);
        vm.assume(amount <= 10_000_000 ether);

        uint256 usdBalance = usd.balanceOf(users.normalUser1);

        // User approves USDai to spend their USD
        vm.startPrank(users.normalUser1);
        usd.approve(address(usdai), amount);

        // User deposits amount of USD into USDai
        uint256 usdaiAmount = usdai.deposit(address(usd), amount, 0, users.normalUser1);

        vm.assume(usdaiAmount > 0);

        // User withdraws usdaiAmount of USDai back to USD
        uint256 usdAmount = usdai.withdraw(address(usd), usdaiAmount, 0, users.normalUser1);

        // Assert user's USDai balance decreased by usdaiAmount
        assertEq(usdai.balanceOf(users.normalUser1), 0);

        // Assert user's USD balance increased by usdAmount less amount
        assertEq(usd.balanceOf(users.normalUser1), usdBalance - amount + usdAmount);

        vm.stopPrank();
    }

    function test__USDaiWithdrawBlacklistedAddress() public {
        vm.startPrank(users.deployer);
        usdai.setBlacklist(users.normalUser1, true);
        vm.stopPrank();

        vm.startPrank(users.normalUser1);
        vm.expectRevert(abi.encodeWithSelector(IUSDai.BlacklistedAddress.selector, users.normalUser1));
        usdai.withdraw(address(usd), 100 ether, 0, users.normalUser1);
        vm.stopPrank();
    }
}

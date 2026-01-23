// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.29;

import "forge-std/Script.sol";

import {BaseYieldEscrow} from "src/BaseYieldEscrow.sol";
import {IUSDai} from "src/interfaces/IUSDai.sol";

import {Deployer} from "./utils/Deployer.s.sol";

contract BaseYieldEscrowSetRateTiers is Deployer {
    function run(uint256[] memory rates, uint256[] memory thresholds) public broadcast useDeployment {
        BaseYieldEscrow baseYieldEscrow = BaseYieldEscrow(_deployment.baseYieldEscrow);

        if (rates.length != thresholds.length) revert InvalidParameter();

        IUSDai.RateTier[] memory rateTiers = new IUSDai.RateTier[](rates.length);
        for (uint256 i; i < rates.length; i++) {
            rateTiers[i].rate = rates[i];
            rateTiers[i].threshold = thresholds[i];
        }

        if (baseYieldEscrow.hasRole(keccak256(bytes("RATE_ADMIN_ROLE")), msg.sender)) {
            baseYieldEscrow.setRateTiers(rateTiers);
        } else {
            console.log("\nCalldata");
            console.log("Target:   %s", address(baseYieldEscrow));
            console.log("Calldata:");
            console.logBytes(abi.encodeWithSelector(BaseYieldEscrow.setRateTiers.selector, rateTiers));
        }
    }
}

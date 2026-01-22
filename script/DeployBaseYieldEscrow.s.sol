// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.29;

import "forge-std/Script.sol";

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {BaseYieldEscrow} from "src/BaseYieldEscrow.sol";

import {Deployer} from "./utils/Deployer.s.sol";

contract DeployBaseYieldEscrow is Deployer {
    function run(
        address deployer,
        address baseToken,
        address multisig
    ) public broadcast useDeployment returns (address) {
        // Deploy BaseYieldEscrow implementation
        BaseYieldEscrow baseYieldEscrowImpl = new BaseYieldEscrow(_deployment.USDai, baseToken);
        console.log("BaseYieldEscrow implementation", address(baseYieldEscrowImpl));

        // Deploy BaseYieldEscrow proxy
        TransparentUpgradeableProxy baseYieldEscrow = new TransparentUpgradeableProxy(
            address(baseYieldEscrowImpl),
            deployer,
            abi.encodeWithSelector(BaseYieldEscrow.initialize.selector, multisig)
        );
        console.log("BaseYieldEscrow proxy", address(baseYieldEscrow));

        _deployment.baseYieldEscrow = address(baseYieldEscrow);

        return (address(baseYieldEscrow));
    }
}

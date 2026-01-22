// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.29;

import "forge-std/Script.sol";

import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";

import {BaseYieldEscrow} from "src/BaseYieldEscrow.sol";

import {Deployer} from "./utils/Deployer.s.sol";

contract UpgradeBaseYieldEscrow is Deployer {
    function run() public broadcast useDeployment returns (address) {
        // Deploy BaseYieldEscrow implementation
        BaseYieldEscrow baseYieldEscrowImpl =
            new BaseYieldEscrow(_deployment.USDai, BaseYieldEscrow(_deployment.baseYieldEscrow).baseToken());
        console.log("BaseYieldEscrow implementation", address(baseYieldEscrowImpl));

        /* Lookup proxy admin */
        address proxyAdmin = address(uint160(uint256(vm.load(_deployment.baseYieldEscrow, ERC1967Utils.ADMIN_SLOT))));

        if (Ownable(proxyAdmin).owner() == msg.sender) {
            /* Upgrade Proxy */
            ProxyAdmin(proxyAdmin).upgradeAndCall(
                ITransparentUpgradeableProxy(_deployment.baseYieldEscrow), address(baseYieldEscrowImpl), ""
            );
            console.log(
                "Upgraded proxy %s implementation to: %s\n", _deployment.baseYieldEscrow, address(baseYieldEscrowImpl)
            );
        } else {
            console.log("\nUpgrade calldata");
            console.log("Target:   %s", proxyAdmin);
            console.log("Calldata:");
            console.logBytes(
                abi.encodeWithSelector(
                    ProxyAdmin.upgradeAndCall.selector,
                    ITransparentUpgradeableProxy(_deployment.baseYieldEscrow),
                    address(baseYieldEscrowImpl),
                    ""
                )
            );
        }

        return address(baseYieldEscrowImpl);
    }
}

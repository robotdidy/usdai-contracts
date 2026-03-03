// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

import "../StakedUSDaiStorage.sol";
import "./PositionManager.sol";

import "../interfaces/IBasePositionManager.sol";

/**
 * @title Base Position Manager
 * @author MetaStreet Foundation
 */
abstract contract BasePositionManager is
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable,
    PositionManager,
    StakedUSDaiStorage,
    IBasePositionManager
{
    /*------------------------------------------------------------------------*/
    /* Immutable state */
    /*------------------------------------------------------------------------*/

    /**
     * @notice Admin fee rate
     */
    uint256 internal immutable _baseYieldAdminFeeRate;

    /*------------------------------------------------------------------------*/
    /* Constructor */
    /*------------------------------------------------------------------------*/

    /**
     * @notice Constructor
     * @param baseYieldAdminFeeRate_ Base yield admin fee rate
     */
    constructor(
        uint256 baseYieldAdminFeeRate_
    ) {
        _baseYieldAdminFeeRate = baseYieldAdminFeeRate_;
    }

    /*------------------------------------------------------------------------*/
    /* Internal helpers */
    /*------------------------------------------------------------------------*/

    /**
     * @inheritdoc PositionManager
     */
    function _assets(
        ValuationType
    ) internal view virtual override returns (uint256) {
        /* Get base yield accrued */
        uint256 baseYieldAccrued = _usdai.baseYieldAccrued();

        /* Calculate admin fee */
        uint256 adminFee = (baseYieldAccrued * _baseYieldAdminFeeRate) / BASIS_POINTS_SCALE;

        /* Return total assets in terms of USDai */
        return baseYieldAccrued - adminFee;
    }

    /*------------------------------------------------------------------------*/
    /* Getter */
    /*------------------------------------------------------------------------*/

    /**
     * @inheritdoc IBasePositionManager
     */
    function claimableBaseYield() external view returns (uint256) {
        return _usdai.baseYieldAccrued();
    }

    /*------------------------------------------------------------------------*/
    /* Permissioned API */
    /*------------------------------------------------------------------------*/

    /**
     * @inheritdoc IBasePositionManager
     */
    function harvestBaseYield() external onlyRole(STRATEGY_ADMIN_ROLE) nonReentrant returns (uint256, uint256) {
        /* Harvest base yield */
        uint256 usdaiAmount = _usdai.harvest();

        /* Calculate admin fee */
        uint256 adminFee = (usdaiAmount * _baseYieldAdminFeeRate) / BASIS_POINTS_SCALE;

        /* Transfer admin fee to admin fee recipient */
        if (adminFee > 0) {
            _usdai.transfer(_adminFeeRecipient, adminFee);

            /* Calculate amount less admin fee */
            usdaiAmount -= adminFee;
        }

        /* Update deposits balance */
        _getDepositsStorage().balance += usdaiAmount;

        /* Emit BaseYieldDeposited */
        emit BaseYieldDeposited(usdaiAmount, adminFee);

        return (usdaiAmount, adminFee);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {CToken} from "compound-protocol/contracts/CToken.sol";
import {CTokenInterface, CErc20Interface} from "compound-protocol/contracts/CTokenInterfaces.sol";
import {CErc20} from "compound-protocol/contracts/CErc20.sol";
import {CErc20Delegator} from "compound-protocol/contracts/CErc20Delegator.sol";
import {CErc20Delegate} from "compound-protocol/contracts/CErc20Delegate.sol";
import {Unitroller} from "compound-protocol/contracts/Unitroller.sol";
import {Comptroller} from "compound-protocol/contracts/Comptroller.sol";
import {SimplePriceOracle} from "compound-protocol/contracts/SimplePriceOracle.sol";
import {WhitePaperInterestRateModel} from "compound-protocol/contracts/WhitePaperInterestRateModel.sol";
import {InterestRateModel} from "compound-protocol/contracts/InterestRateModel.sol";

contract CompoundSetup is Test {
    address admin = makeAddr("admin");

    ERC20 comp;
    Comptroller comptrollerImplementation;
    Unitroller unitroller;
    Comptroller comptroller; // Meant to be a wrapper of unitroller
    InterestRateModel interestRateModel;
    SimplePriceOracle oracle;

    CErc20Delegate cErc20Delegate;

    function _deployCompound() internal {
        // 1. Unitroller
        // 2. ComptrollerImplementation
        // 3. InterestRateModel
        // 4. Oracle
        // 5. CErc20Delegate
        // 6. ERC20 Token
        // 7. CERC20 Token
        vm.startPrank(admin);
        unitroller = new Unitroller(); // 1
        comptrollerImplementation = new Comptroller(); // 2
        unitroller._setPendingImplementation(address(comptrollerImplementation));
        comptrollerImplementation._become(unitroller);
        comptroller = Comptroller(address(unitroller));
        interestRateModel = new WhitePaperInterestRateModel(0, 0); // 3
        oracle = new SimplePriceOracle(); // 4
        comptroller._setPriceOracle(oracle);
        cErc20Delegate = new CErc20Delegate(); // 5
        vm.stopPrank();

        vm.label(address(unitroller), "Unitroller");
        vm.label(address(comptroller), "Comptroller");
        vm.label(address(interestRateModel), "InterestRateModel");
        vm.label(address(oracle), "Oracle");
    }

    function _bindMarket(CToken cToken) internal {
        comptroller._supportMarket(cToken);
        cToken._setComptroller(comptroller);
        oracle.setUnderlyingPrice(cToken, 1 * 1e18);
    }

    function _enterOneMarket(address cToken) internal {
        address[] memory cTokens = new address[](1);
        cTokens[0] = cToken;
        comptroller.enterMarkets(cTokens);
    }

    function _createCErc20(address underlying, string memory name, string memory symbol) internal returns (CErc20) {
        bytes memory callbackData = new bytes(0);
        CErc20Delegator cToken = new CErc20Delegator(
            address(underlying),
            comptroller,
            interestRateModel,
            1e18,
            name,
            symbol,
            18,
            payable(admin),
            address(cErc20Delegate),
            callbackData
        );
        return CErc20(address(cToken));
    }
}

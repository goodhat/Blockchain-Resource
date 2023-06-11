// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../lib/forge-std/src/Script.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {CToken} from "../lib/compound-protocol/contracts/CToken.sol";
import {CTokenInterface, CErc20Interface} from "../lib/compound-protocol/contracts/CTokenInterfaces.sol";
import {CErc20} from "../lib/compound-protocol/contracts/CErc20.sol";
import {CErc20Delegator} from "../lib/compound-protocol/contracts/CErc20Delegator.sol";
import {CErc20Delegate} from "../lib/compound-protocol/contracts/CErc20Delegate.sol";
import {Unitroller} from "../lib/compound-protocol/contracts/Unitroller.sol";
import {Comptroller} from "../lib/compound-protocol/contracts/Comptroller.sol";
import {SimplePriceOracle} from "../lib/compound-protocol/contracts/SimplePriceOracle.sol";
import {WhitePaperInterestRateModel} from "../lib/compound-protocol/contracts/WhitePaperInterestRateModel.sol";
import {InterestRateModel} from "../lib/compound-protocol/contracts/InterestRateModel.sol";

contract DeployCompoundScript is Script {
    address admin = vm.envAddress("ADMIN");
    uint256 adminKey = vm.envUint("ADMIN_KEY");

    ERC20 comp;
    Comptroller comptrollerImplementation;
    Unitroller unitroller;
    Comptroller comptroller; // Meant to be a wrapper of unitroller
    InterestRateModel interestRateModel;
    SimplePriceOracle oracle;

    CErc20Delegate cErc20Delegate;
    ERC20 apwk;
    CErc20 cApwk;

    // Run:
    // - anvil
    // - forge script scripts/deployCompound.s.sol --rpc-url http://127.0.0.1:8545 --broadcast
    function run() public {
        deployCompound();
    }

    // This command should deploy the main compound set:
    // 1. Unitroller
    // 2. ComptrollerImplementation
    // 3. InterestRateModel
    // 4. Oracle
    // 5. CErc20Delegate
    // 6. ERC20 Token
    // 7. CERC20 Token
    function deployCompound() internal {
        vm.startBroadcast(adminKey);

        unitroller = new Unitroller(); // 1
        comptrollerImplementation = new Comptroller(); // 2
        unitroller._setPendingImplementation(address(comptrollerImplementation));
        comptrollerImplementation._become(unitroller);
        comptroller = Comptroller(address(unitroller));
        interestRateModel = new WhitePaperInterestRateModel(0, 0); // 3
        oracle = new SimplePriceOracle(); // 4
        comptroller._setPriceOracle(oracle);
        cErc20Delegate = new CErc20Delegate(); // 5

        apwk = new ERC20("Appworks Token", "APWK"); // 6
        cApwk = createCErc20(apwk, "CToken of APWK", "cAPWK"); // 7

        bindMarket(cApwk);
        vm.stopBroadcast();
    }

    function bindMarket(CToken cToken) internal {
        comptroller._supportMarket(cToken);
        cToken._setComptroller(comptroller);
        oracle.setUnderlyingPrice(cToken, 1 * 1e18);
    }

    function enterOneMarket(address cToken) internal {
        address[] memory cTokens = new address[](1);
        cTokens[0] = cToken;
        comptroller.enterMarkets(cTokens);
    }

    function createCErc20(ERC20 underlying, string memory name, string memory symbol) internal returns (CErc20) {
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

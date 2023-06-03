// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {EIP20Interface} from "compound-protocol/contracts/EIP20Interface.sol";
import {CErc20} from "compound-protocol/contracts/CErc20.sol";
import "test/helper/CompoundPracticeSetUp.sol";

interface IBorrower {
    function borrow() external;
}

contract CompoundPracticeTest is CompoundPracticeSetUp {
    EIP20Interface public USDC = EIP20Interface(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    CErc20 public cUSDC = CErc20(0x39AA39c021dfbaE8faC545936693aC917d5E7563);
    address public user;

    IBorrower public borrower;

    string _MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");

    function setUp() public override {
        super.setUp();

        vm.makePersistent(address(borrowerAddress));
        vm.createSelectFork(_MAINNET_RPC_URL);
        vm.rollFork(12299047);

        // Deployed in CompoundPracticeSetUp helper
        borrower = IBorrower(borrowerAddress);

        user = makeAddr("User");

        uint256 initialBalance = 10000 * 10 ** USDC.decimals();
        deal(address(USDC), user, initialBalance);

        vm.label(address(cUSDC), "cUSDC");
        vm.label(borrowerAddress, "Borrower");
    }

    function test_compound_mint_interest() public {
        vm.startPrank(user);
        // TODO: 1. Mint some cUSDC with USDC
        uint256 borrowAmount = USDC.balanceOf(user);
        USDC.approve(address(cUSDC), borrowAmount);
        cUSDC.mint(borrowAmount);

        // TODO: 2. Modify block state to generate interest
        vm.rollFork(block.number + 100);

        // TODO: 3. Redeem and check the redeemed amount
        uint256 success = cUSDC.redeem(cUSDC.balanceOf(user));
        assert(success == 0);
        // assertEq(EIP20Interface(USDC).balanceOf(user), borrowAmount);
        console.log(borrowAmount);
        console.log(EIP20Interface(USDC).balanceOf(user));
    }

    function test_compound_mint_interest_with_borrower() public {
        vm.startPrank(user);
        // TODO: 1. Mint some cUSDC with USDC
        uint256 borrowAmount = USDC.balanceOf(user);
        USDC.approve(address(cUSDC), borrowAmount);
        cUSDC.mint(borrowAmount);

        // 2. Borrower.borrow() will borrow some USDC
        borrower.borrow();

        // // TODO: 3. Modify block state to generate interest
        vm.rollFork(block.number + 100);

        // // TODO: 4. Redeem and check the redeemed amount
        cUSDC.redeem(cUSDC.balanceOf(user));
        console.log(borrowAmount);
        console.log(EIP20Interface(USDC).balanceOf(user));
    }
}

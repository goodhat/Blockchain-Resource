// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import "../scripts/deployCompound.s.sol";
import "compound-protocol/contracts/ErrorReporter.sol";

contract CompoundHWTest is Test, DeployCompoundScript {
    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");
    ERC20 bpwk = new ERC20("Appworks Token B", "BPWK");
    CErc20 cBpwk = createCErc20(bpwk, "CToken of BppWork Token", "cBPWK");

    function setUp() public {
        deployCompound();
        bpwk = new ERC20("Appworks Token B", "BPWK");
        cBpwk = createCErc20(bpwk, "CToken of BppWork Token", "cBPWK");

        vm.label(address(comptroller), "Comptroller");
        vm.label(address(oracle), "Oracle");
        vm.label(admin, "Admin");
        vm.label(address(apwk), "APWK");
        vm.label(address(bpwk), "BPWK");
        vm.label(address(cApwk), "cAPWK");
        vm.label(address(cBpwk), "cBPWK");
    }

    function testMintAndRedeem() public {
        uint256 amount = 100 * 1e18;
        deal(address(apwk), user1, amount);
        vm.startPrank(user1);
        apwk.approve(address(cApwk), amount);
        cApwk.mint(amount);
        assertEq(cApwk.balanceOf(user1), amount);

        cApwk.redeem(amount);
        vm.stopPrank();
        assertEq(cApwk.balanceOf(user1), 0);
        assertEq(apwk.balanceOf(user1), amount);
    }

    function testUser1BorrowAndRepay() public {
        vm.startPrank(admin);
        bindMarket(cBpwk);
        oracle.setUnderlyingPrice(cApwk, 1 * 1e18);
        oracle.setUnderlyingPrice(cBpwk, 100 * 1e18);
        uint256 success = comptroller._setCollateralFactor(cBpwk, 0.5 * 1e18);
        assertEq(success, 0);

        // Put some money into cApwk
        deal(address(apwk), user2, 20000 * 1e18);
        changePrank(user2);
        apwk.approve(address(cApwk), 10000 * 1e18);
        cApwk.mint(10000 * 1e18);

        // User 1 deposit 1 bpwk and make it collateral.
        deal(address(bpwk), user1, 1e18);
        changePrank(user1);
        bpwk.approve(address(cBpwk), 1e18);
        cBpwk.mint(1e18);
        enterOneMarket(address(cBpwk)); // user1 use bpwk as collateral

        // Cannot borrow if exceeding collateral factor
        vm.expectRevert();
        cApwk.borrow(51 * 1e18);

        // Borrow
        cApwk.borrow(50 * 1e18);
        assertEq(apwk.balanceOf(user1), 50 * 1e18);

        // Repay
        apwk.approve(address(cApwk), 25 * 1e18);
        cApwk.repayBorrow(25 * 1e18);
        assertEq(apwk.balanceOf(user1), 25 * 1e18);

        // // Borrow 50 apwk in order to do the next test.
        cApwk.borrow(25 * 1e18);
        vm.stopPrank();
    }

    function testUser2LiquidateUser1ByLoweringCollateralFactor() public {
        // Use previous setup:
        // User 1 has 1 cBpwk as collateral, and borrows 50 apwk.
        testUser1BorrowAndRepay();

        // Set collateral factor and close factor
        vm.startPrank(admin);
        uint256 success = comptroller._setCollateralFactor(cBpwk, 0.4 * 1e18);
        assertEq(success, 0);
        success = comptroller._setCloseFactor(0.8 * 1e18);
        assertEq(success, 0);
        success = comptroller._setLiquidationIncentive(1.1 * 1e18);
        assertEq(success, 0);

        // Cannot liquidate if exceeding close factor
        changePrank(user2);
        apwk.approve(address(cApwk), 45 * 1e18);
        vm.expectRevert();
        cApwk.liquidateBorrow(user1, 45 * 1e18, cBpwk);

        // Liquidate
        success = cApwk.liquidateBorrow(user1, 40 * 1e18, cBpwk);
        assertEq(success, 0);

        // 40 * 1e18 * (1 * 1e18 / 100 * 1e18) * 1.1 * 97.2%
        // console.log(cBpwk.balanceOf(user2)); // 427680000000000000
    }

    function testUser2LiquidateUser1ByLoweringPrice() public {
        // Use previous setup:
        // User 1 has 1 cBpwk as collateral, and borrows 50 apwk.
        testUser1BorrowAndRepay();

        // Lower price of collateral
        vm.startPrank(admin);
        oracle.setUnderlyingPrice(cBpwk, 80 * 1e18);

        // Set close factor and liquidation incentive
        uint256 success = comptroller._setCloseFactor(0.8 * 1e18);
        assertEq(success, 0);
        success = comptroller._setLiquidationIncentive(1.1 * 1e18);
        assertEq(success, 0);

        // Cannot liquidate if exceeding close factor
        changePrank(user2);
        apwk.approve(address(cApwk), 45 * 1e18);
        vm.expectRevert();
        cApwk.liquidateBorrow(user1, 45 * 1e18, cBpwk);

        // Liquidate
        success = cApwk.liquidateBorrow(user1, 40 * 1e18, cBpwk);
        assertEq(success, 0);

        // 40 * 1e18 * (1 * 1e18 / 80 * 1e18) * 1.1 * 97.2%
        // console.log(cBpwk.balanceOf(user2)); // 534600000000000000
    }
}

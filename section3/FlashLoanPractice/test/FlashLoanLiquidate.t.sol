pragma solidity 0.8.19;

import "forge-std/Test.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {CErc20} from "compound-protocol/contracts/CErc20.sol";

import "./helper/CompoundSetup.t.sol";
import "../src/FlashLoanLiquidate.sol";

contract FlashSwapLiquidateTest is CompoundSetup {
    IERC20 public UNI = IERC20(0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984);
    IERC20 public USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    CErc20 public cUNI;
    CErc20 public cUSDC;

    uint256 public success;

    address richGuy = makeAddr("richGuy");
    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");

    function setUp() public {
        string memory rpc = vm.envString("MAINNET_RPC_URL");
        vm.createSelectFork(rpc);
        vm.rollFork(17465000);
        _deployCompound();

        vm.startPrank(admin);
        cUNI = _createCErc20(address(UNI), "cToken of UNI", "cUNI");
        cUSDC = _createCErc20(address(USDC), "cToken of USDC", "cUSDC");
        _bindMarket(cUNI);
        _bindMarket(cUSDC);

        success = comptroller._setCloseFactor(0.5 * 1e18);
        assertEq(success, 0);
        success = comptroller._setLiquidationIncentive(1.08 * 1e18);
        assertEq(success, 0);
        success = comptroller._setCollateralFactor(cUNI, 0.5 * 1e18);
        assertEq(success, 0);

        oracle.setUnderlyingPrice(cUNI, 5 * 1e18);
        oracle.setUnderlyingPrice(cUSDC, 1 * 1e30);

        changePrank(richGuy);
        deal(address(UNI), richGuy, 1e6 * 1e18); // 1 million of UNI
        deal(address(USDC), richGuy, 1e6 * 1e6); // 1 million of USDC
        UNI.approve(address(cUNI), 1e6 * 1e18);
        USDC.approve(address(cUSDC), 1e6 * 1e6);
        cUNI.mint(1e6 * 1e18);
        cUSDC.mint(1e6 * 1e6);
        vm.stopPrank();

        vm.label(user1, "USER 1");
        vm.label(user2, "USER 2");
        vm.label(address(UNI), "UNI");
        vm.label(address(USDC), "USDC");
        vm.label(address(cUNI), "cUNI");
        vm.label(address(cUSDC), "cUSDC");
    }

    function testFlashLoanLiquidation() public {
        deal(address(UNI), user1, 1000 * 1e18);
        vm.startPrank(user1);
        UNI.approve(address(cUNI), 1000 * 1e18);
        cUNI.mint(1000 * 1e18);
        _enterOneMarket(address(cUNI));
        cUSDC.borrow(2500 * 1e6);

        changePrank(admin);
        oracle.setUnderlyingPrice(cUNI, 4 * 1e18);

        changePrank(user2);

        FlashLoanLiquidate.LiquidateParams memory p;
        p.borrower = user1;
        p.amount = 1250 * 1e6;
        p.cTokenDebt = cUSDC;
        p.cTokenCollateral = cUNI;
        p.tokenDebt = USDC;
        p.tokenCollateral = UNI;
        p.tokenOut = USDC;
        p.to = user2;

        FlashLoanLiquidate f = new FlashLoanLiquidate();
        f.execute(p);
        vm.stopPrank();

        uint256 profit = USDC.balanceOf(user2);
        console.log("Final profit: %s.%s USDC", profit / 1e6, profit % 1e6);
        // Final profit: 63.638693
    }
}

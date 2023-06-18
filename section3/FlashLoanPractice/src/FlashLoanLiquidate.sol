pragma solidity 0.8.19;

import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {CErc20} from "compound-protocol/contracts/CErc20.sol";
import "forge-std/Test.sol";
import {
    IFlashLoanSimpleReceiver,
    IPoolAddressesProvider,
    IPool
} from "aave-v3-core/contracts/flashloan/interfaces/IFlashLoanSimpleReceiver.sol";

import "forge-std/Test.sol";

interface ISwapRouter {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);
}

contract FlashLoanLiquidate is IFlashLoanSimpleReceiver {
    struct LiquidateParams {
        address borrower;
        uint256 amount;
        CErc20 cTokenDebt;
        CErc20 cTokenCollateral;
        IERC20 tokenDebt;
        IERC20 tokenCollateral;
        IERC20 tokenOut;
        address to;
    }

    address constant POOL_ADDRESSES_PROVIDER = 0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e;
    address constant SWAP_ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;

    function execute(LiquidateParams memory p) public {
        POOL().flashLoanSimple(address(this), address(p.tokenDebt), p.amount, abi.encode(p), 0);
        p.tokenOut.transfer(p.to, p.tokenOut.balanceOf(address(this)));
    }

    function executeOperation(address asset, uint256 amount, uint256 premium, address initiator, bytes calldata params)
        external
        returns (bool)
    {
        require(initiator == address(this), "Wrong initiator");
        (LiquidateParams memory p) = abi.decode(params, (LiquidateParams));

        // 1. Liquidate user 1 and get cUNI
        IERC20(asset).approve(address(p.cTokenDebt), amount);
        uint256 success = p.cTokenDebt.liquidateBorrow(p.borrower, amount, p.cTokenCollateral);
        require(success == 0, "Liquidate borrow failed");

        // 2. Redeem cUNI and get UNI
        success = p.cTokenCollateral.redeem(p.cTokenCollateral.balanceOf(address(this)));
        require(success == 0, "Redeem failed");

        // 3. Swap UNI for USDC
        uint256 collateralBalance = p.tokenCollateral.balanceOf(address(this));
        p.tokenCollateral.approve(SWAP_ROUTER, collateralBalance);
        ISwapRouter.ExactInputSingleParams memory swapParams = ISwapRouter.ExactInputSingleParams({
            tokenIn: address(p.tokenCollateral),
            tokenOut: address(p.tokenOut),
            fee: 3000, // 0.3%
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: collateralBalance,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });
        uint256 amountOut = ISwapRouter(SWAP_ROUTER).exactInputSingle(swapParams);

        // 4. Check if profitable.
        require(amountOut > amount + premium, "Not profitable");

        // 5. Approve USDC to repay aave
        IERC20(asset).approve(msg.sender, amount + premium);
        return true;
    }

    function ADDRESSES_PROVIDER() public pure returns (IPoolAddressesProvider) {
        return IPoolAddressesProvider(POOL_ADDRESSES_PROVIDER);
    }

    function POOL() public view returns (IPool) {
        return IPool(ADDRESSES_PROVIDER().getPool());
    }
}

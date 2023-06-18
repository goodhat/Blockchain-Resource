pragma solidity 0.8.19;

import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {BalanceChecker} from "./BalanceChecker.sol";
import {
    IFlashLoanSimpleReceiver,
    IPoolAddressesProvider,
    IPool
} from "aave-v3-core/contracts/flashloan/interfaces/IFlashLoanSimpleReceiver.sol";

// TODO: Inherit IFlashLoanSimpleReceiver
contract AaveFlashLoan is IFlashLoanSimpleReceiver {
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant POOL_ADDRESSES_PROVIDER = 0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e;

    struct Params {
        address checker;
    }

    function execute(BalanceChecker checker) external {
        // TODO
        Params memory params;
        params.checker = address(checker);
        POOL().flashLoanSimple(address(this), USDC, 10_000_000 * 10 ** 6, abi.encode(params), 0);
    }

    function executeOperation(address asset, uint256 amount, uint256 premium, address initiator, bytes calldata params)
        external
        returns (bool)
    {
        require(initiator == address(this));
        (Params memory p) = abi.decode(params, (Params));
        BalanceChecker(p.checker).checkBalance();

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

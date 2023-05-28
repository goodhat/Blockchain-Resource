// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {ISimpleSwap} from "./interface/ISimpleSwap.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract SimpleSwap is ISimpleSwap, ERC20("Simple Swap LP Token", "SSLP") {
    // Implement core logic here
    address private tokenA;
    address private tokenB;

    uint256 private reserveA;
    uint256 private reserveB;

    constructor(address _tokenA, address _tokenB) {
        require(_tokenA.code.length > 0, "SimpleSwap: TOKENA_IS_NOT_CONTRACT");
        require(_tokenB.code.length > 0, "SimpleSwap: TOKENB_IS_NOT_CONTRACT");
        require(_tokenA != _tokenB, "SimpleSwap: TOKENA_TOKENB_IDENTICAL_ADDRESS");
        if (_tokenA < _tokenB) {
            tokenA = _tokenA;
            tokenB = _tokenB;
        } else {
            tokenA = _tokenB;
            tokenB = _tokenA;
        }
    }

    function getReserves() public view override returns (uint256, uint256) {
        return (reserveA, reserveB);
    }

    function getTokenA() external view override returns (address) {
        return tokenA;
    }

    function getTokenB() external view override returns (address) {
        return tokenB;
    }

    function swap(address tokenIn, address tokenOut, uint256 amountIn) external override returns (uint256 amountOut) {
        address _tokenA = tokenA;
        address _tokenB = tokenB;
        require(tokenIn != tokenOut, "SimpleSwap: IDENTICAL_ADDRESS");
        require(tokenIn == _tokenA || tokenIn == _tokenB, "SimpleSwap: INVALID_TOKEN_IN");
        require(tokenOut == _tokenA || tokenOut == _tokenB, "SimpleSwap: INVALID_TOKEN_OUT");
        require(amountIn > 0, "SimpleSwap: INSUFFICIENT_INPUT_AMOUNT");

        (uint256 _reserveA, uint256 _reserveB) = getReserves();
        uint256 k = _reserveA * _reserveB;
        if (tokenIn == tokenA) {
            // amountOut = _reserveB * 10 - k * 10 / (_reserveA + amountIn);
            amountOut = amountIn * _reserveB / (_reserveA + amountIn);
        } else {
            // amountOut = _reserveA * 10 - k * 10 / (_reserveB + amountIn);
            amountOut = amountIn * _reserveA / (_reserveB + amountIn);
        }
        ERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        ERC20(tokenOut).transfer(msg.sender, amountOut);
        emit Swap(msg.sender, tokenIn, tokenOut, amountIn, amountOut);

        _update();
        (_reserveA, _reserveB) = getReserves();
        require(_reserveA * _reserveB >= k, "SimpleSwap: K");
    }

    function addLiquidity(uint256 amountAIn, uint256 amountBIn)
        external
        override
        returns (uint256 amountA, uint256 amountB, uint256 liquidity)
    {
        require(amountAIn > 0 && amountBIn > 0, "SimpleSwap: INSUFFICIENT_INPUT_AMOUNT");
        if (totalSupply() == 0) {
            amountA = amountAIn;
            amountB = amountBIn;
        } else {
            (amountA, amountB) = _quote(amountAIn, amountBIn);
        }
        liquidity = Math.sqrt(amountA * amountB);
        _mint(msg.sender, liquidity);
        emit AddLiquidity(msg.sender, amountA, amountB, liquidity);

        ERC20(tokenA).transferFrom(msg.sender, address(this), amountA);
        ERC20(tokenB).transferFrom(msg.sender, address(this), amountB);
        _update();
    }

    function removeLiquidity(uint256 liquidity) external override returns (uint256 amountA, uint256 amountB) {
        require(liquidity > 0, "SimpleSwap: INSUFFICIENT_LIQUIDITY_BURNED");
        // require(balanceOf(msg.sender) >= liquidity, "SimpleSwap: INSUFFICIENT_LIQUIDITY_BURNED");

        amountA = reserveA * liquidity / totalSupply();
        amountB = reserveB * liquidity / totalSupply();
        ERC20(address(this)).transferFrom(msg.sender, address(this), liquidity);
        _burn(address(this), liquidity);
        emit RemoveLiquidity(msg.sender, amountA, amountB, liquidity);

        ERC20(tokenA).transfer(msg.sender, amountA);
        ERC20(tokenB).transfer(msg.sender, amountB);
    }

    function _quote(uint256 amountAIn, uint256 amountBIn)
        private
        view
        returns (uint256 actualAmountA, uint256 actualAmountB)
    {
        (uint256 _reserveA, uint256 _reserveB) = getReserves();
        if (amountAIn * _reserveB > amountBIn * _reserveA) {
            actualAmountA = amountBIn * _reserveA / _reserveB;
            actualAmountB = amountBIn;
        } else {
            actualAmountA = amountAIn;
            actualAmountB = amountAIn * _reserveB / _reserveA;
        }
    }

    function _update() private {
        reserveA = ERC20(tokenA).balanceOf(address(this));
        reserveB = ERC20(tokenB).balanceOf(address(this));
    }
}

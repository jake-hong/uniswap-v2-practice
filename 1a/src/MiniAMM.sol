// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import {IMiniAMM, IMiniAMMEvents} from "./IMiniAMM.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Add as many variables or functions as you would like
// for the implementation. The goal is to pass `forge test`.
contract MiniAMM is IMiniAMM, IMiniAMMEvents {
    uint256 public k = 0;
    uint256 public xReserve = 0;
    uint256 public yReserve = 0;

    address public tokenX;
    address public tokenY;

    // implement constructor
    constructor(address _tokenX, address _tokenY) {
        require(_tokenX != address(0), "tokenX cannot be zero address");
        require(_tokenY != address(0), "tokenY cannot be zero address");
        require(_tokenX != _tokenY, "Tokens must be different");

        if (_tokenX < _tokenY) {
            tokenX = _tokenX;
            tokenY = _tokenY;
        } else {
            tokenX = _tokenY;
            tokenY = _tokenX;
        }
    }

    // add parameters and implement function.
    // this function will determine the initial 'k'.
    function _addLiquidityFirstTime(
        uint256 xAmountIn,
        uint256 yAmountIn
    ) internal {
        IERC20(tokenX).transferFrom(msg.sender, address(this), xAmountIn);
        IERC20(tokenY).transferFrom(msg.sender, address(this), yAmountIn);

        xReserve = xAmountIn;
        yReserve = yAmountIn;

        // x*y = k
        k = xAmountIn * yAmountIn;
    }

    // add parameters and implement function.
    // this function will increase the 'k'
    // because it is transferring liquidity from users to this contract.
    function _addLiquidityNotFirstTime(
        uint256 xAmountIn,
        uint256 yAmountIn
    ) internal {
        // 현재 비율에 맞는 필요한 토큰 양 계산
        uint256 yRequired = (xAmountIn * yReserve) / xReserve;

        // 사용자가 제공한 Y 토큰이 충분한지 확인
        require(yAmountIn >= yRequired, "Insufficient Y token amount");

        IERC20(tokenX).transferFrom(msg.sender, address(this), xAmountIn);
        IERC20(tokenY).transferFrom(msg.sender, address(this), yRequired);

        xReserve += xAmountIn;
        yReserve += yRequired;

        k = xReserve * yReserve;
    }

    // complete the function
    function addLiquidity(uint256 xAmountIn, uint256 yAmountIn) external {
        require(
            xAmountIn > 0 && yAmountIn > 0,
            "Amounts must be greater than 0"
        );
        if (k == 0) {
            _addLiquidityFirstTime(xAmountIn, yAmountIn);
        } else {
            _addLiquidityNotFirstTime(xAmountIn, yAmountIn);
        }
        emit AddLiquidity(xAmountIn, yAmountIn);
    }

    // complete the function
    function swap(uint256 xAmountIn, uint256 yAmountIn) external {
        require(k > 0, "No liquidity in pool");
        require(xAmountIn > 0 || yAmountIn > 0, "Must swap at least one token");
        require(
            !(xAmountIn > 0 && yAmountIn > 0),
            "Can only swap one direction at a time"
        );

        uint256 xOut = 0;
        uint256 yOut = 0;

        if (xAmountIn > 0) {
            require(xAmountIn < xReserve, "Insufficient liquidity");

            yOut = yReserve - (k / (xReserve + xAmountIn));

            IERC20(tokenX).transferFrom(msg.sender, address(this), xAmountIn);
            IERC20(tokenY).transfer(msg.sender, yOut);

            xReserve += xAmountIn;
            yReserve -= yOut;
        } else {
            require(yAmountIn < yReserve, "Insufficient liquidity");

            xOut = xReserve - (k / (yReserve + yAmountIn));

            IERC20(tokenY).transferFrom(msg.sender, address(this), yAmountIn);
            IERC20(tokenX).transfer(msg.sender, xOut);

            yReserve += yAmountIn;
            xReserve -= xOut;
        }

        k = xReserve * yReserve;

        emit Swap(
            xAmountIn > 0 ? xAmountIn : yAmountIn,
            xAmountIn > 0 ? yOut : xOut
        );
    }
}

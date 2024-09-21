// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "./interface/IERC20.sol";
import "./interface/ISwapFactory.sol";
import "./interface/ISwapPair.sol";

library PriceLibrary {

    struct TInfoS {
        bool isBurn;
        bool isSwap;
        bool isToFunder;
        bool isSwapBurnDBTC;
        uint256 burnFee;
        uint256 swapFee;
        uint256 toFunder;
        uint256 _SBF;
        uint256 SlippageFee;
        address pair;
    }
    function getPrice(
        IERC20 token,
        address usd,
        ISwapFactory swapFactory,
        mapping(address => TInfoS) storage tInfo
    ) internal view returns (uint256 price) {
        if (address(token) == usd) {
            return 1 ether;
        }

        uint256 ds = 10 ** token.decimals();
        address pair = tInfo[address(token)].pair;

        if (pair == address(0)) {
            address _PA = swapFactory.getPair(address(token), usd);
            ISwapPair mainPair = ISwapPair(_PA);

            (uint256 reserve0, uint256 reserve1,) = mainPair.getReserves();

            if (mainPair.token0() == address(token)) {
                return reserve1 * ds / reserve0;
            } else {
                return reserve0 * ds / reserve1;
            }
        } else {
            (uint256 reserve01, uint256 reserve11,) = ISwapPair(pair).getReserves();

            uint256 price0 = 0;
            address _t0;

            if (ISwapPair(pair).token0() == address(token)) {
                price0 = reserve11 * ds / reserve01;
                _t0 = ISwapPair(pair).token1();
            } else {
                price0 = reserve01 * ds / reserve11;
                _t0 = ISwapPair(pair).token0();
            }

            address _PA = swapFactory.getPair(_t0, usd);
            ISwapPair mainPair = ISwapPair(_PA);

            (uint256 reserve0, uint256 reserve1,) = mainPair.getReserves();

            uint256 price2 = 0;

            if (mainPair.token0() == _t0) {
                price2 = reserve1 * 10 ** IERC20(_t0).decimals() / reserve0;
            } else {
                price2 = reserve0 * 10 ** IERC20(usd).decimals() / reserve1;
            }

            return price0 * price2 / 10 ** IERC20(_t0).decimals();
        }
    }
}

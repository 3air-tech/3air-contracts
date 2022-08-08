// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.9;

interface IPriceConverter {

    function getTokenAmount(uint256 usdPrice) external view returns (uint256 tokenAmount);

}
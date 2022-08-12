// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.9;

interface IAutomaticStaking {

    function stakeForAddress(address accountAddress, uint256 amount) external;

}
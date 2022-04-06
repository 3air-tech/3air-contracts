// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface ISecurityProxy {
    function validateTransfer(address from, address to, uint256 amount) external view returns (bool);
}

/// @custom:security-contact info@3air.io
contract Air is Ownable, ERC20, ERC20Burnable, ERC20Permit, ERC20Votes {


    address private securityProxyAddress;
    bool public securityProxyDisabled;

    constructor() ERC20("3air", "3AIR") ERC20Permit("3air") {

        _mint(msg.sender, 1000000000 * 10 ** decimals());

        securityProxyAddress = address(0);
        securityProxyDisabled = false;
    }

    function _afterTokenTransfer(address from, address to, uint256 amount)
    internal
    override(ERC20, ERC20Votes)
    {
        super._afterTokenTransfer(from, to, amount);
    }


    function _beforeTokenTransfer(address from, address to, uint256 amount)
    internal
    override(ERC20)
    {

        if(securityProxyAddress != address(0)) {
            require(ISecurityProxy(securityProxyAddress).validateTransfer(from, to, amount), "Transfer not allowed");
        }

        super._beforeTokenTransfer(from, to, amount);
    }

    function _mint(address to, uint256 amount)
    internal
    override(ERC20, ERC20Votes)
    {
        super._mint(to, amount);
    }

    function _burn(address account, uint256 amount)
    internal
    override(ERC20, ERC20Votes)
    {
        super._burn(account, amount);
    }

    function setSecurityProxy(address _securityProxy) public onlyOwner {

        require(!securityProxyDisabled, "Security proxy was already disabled");
        securityProxyAddress = _securityProxy;
    }

    function disableSecurityProxy() public onlyOwner {

        securityProxyDisabled = true;
        securityProxyAddress = address(0);
    }
}

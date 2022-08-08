// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";

contract VerifiableCredentialRegistry is Ownable {


    event Revoked(bytes16 verifiableCredentialID);
    event Issued(address user, bytes16 verifiableCredentialID);


    mapping(address => bytes16[]) private userPublicKeyToIssuedVCs;
    mapping(bytes16 => address) private VerifiableCredentialIDToUserPublicKey;
    mapping(bytes16 => uint256) private revocations;

    function revoked(bytes16 verifiableCredentialID) public view returns (uint256) {
        return revocations[verifiableCredentialID];
    }

    function revoke(bytes16 verifiableCredentialID) public onlyOwner {
        require(revocations[verifiableCredentialID] == 0);
        revocations[verifiableCredentialID] = block.number;
        emit Revoked(verifiableCredentialID);
    }

    function issue(address user, bytes16 verifiableCredentialID) public onlyOwner {
        VerifiableCredentialIDToUserPublicKey[verifiableCredentialID] = user;
        userPublicKeyToIssuedVCs[user].push(verifiableCredentialID);
        emit Issued(user, verifiableCredentialID);
    }


    function user(bytes16 verifiableCredentialID) public view returns (address) {
        require(VerifiableCredentialIDToUserPublicKey[verifiableCredentialID] != address(0x0000000000000000));
        return VerifiableCredentialIDToUserPublicKey[verifiableCredentialID];
    }

    function verifiableCredentials(address user) public view returns (bytes16[] memory) {
        require(userPublicKeyToIssuedVCs[user].length > 0);
        return userPublicKeyToIssuedVCs[user];
    }



}

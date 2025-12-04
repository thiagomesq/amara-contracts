// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";

contract Registry is AccessControl {
    bytes32 public constant UPDATER_ROLE = keccak256("UPDATER_ROLE");

    mapping(bytes32 => address) private _addresses;

    //Events
    event AddressSet(bytes32 indexed id, address indexed contractAddress);

    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(UPDATER_ROLE, admin);
    }

    function setAddress(bytes32 id, address contractAddress) external onlyRole(UPDATER_ROLE) {
        _addresses[id] = contractAddress;
        emit AddressSet(id, contractAddress);
    }

    function getAddress(bytes32 id) external view returns (address) {
        return _addresses[id];
    }
}

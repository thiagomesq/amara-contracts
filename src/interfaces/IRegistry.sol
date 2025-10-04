// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IRegistry {
    function getAddress(bytes32 id) external view returns (address);
}

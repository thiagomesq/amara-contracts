// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract MockERC20Permit is ERC20, ERC20Permit {
    constructor(string memory name, string memory symbol, address initialAccount, uint256 initialBalance) ERC20(name, symbol) ERC20Permit(name) {
        _mint(initialAccount, initialBalance);
    }

    function getPermitDigest(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline
    ) public view returns (bytes32) {
        bytes32 digest = keccak256(
            abi.encodePacked(
                '\x19\x01',
                _domainSeparatorV4(),
                keccak256(abi.encode(keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"), owner, spender, value, nonces(owner), deadline))
            )
        );
        return digest;
    }
}

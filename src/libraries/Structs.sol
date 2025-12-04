// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title Structs
 * @author Cascade
 * @notice Defines shared data structures for the Amara protocol.
 */
library Structs {
    struct Attribute {
        string trait_type;
        string value;
    }

    struct Metadata {
        string name;
        string description;
        string image;
        Attribute[] attributes;
    }
}

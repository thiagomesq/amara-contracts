// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {TestBase} from "./TestBase.sol";
import {EntityToken} from "../src/EntityToken.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";

contract EntityTokenTest is TestBase {
    bytes32 private constant DUMMY_HASH = keccak256("dummy");
    string private constant TOKEN_URI = "ipfs://some-hash";

    function setUp() public override {
        super.setUp();
    }

    function test_SafeMint() public {
        vm.prank(address(entityManager)); // Mock call from EntityManager
        entityToken.safeMint(CONTRIBUTOR_ACCOUNT, DUMMY_HASH, Base64.encode(bytes(TOKEN_URI)));

        assertEq(entityToken.ownerOf(1), CONTRIBUTOR_ACCOUNT);
        string memory expectedURI =
            string(abi.encodePacked("data:application/json;base64,", Base64.encode(bytes(TOKEN_URI))));
        assertEq(entityToken.tokenURI(1), expectedURI);
    }

    function test_RevertIf_UnauthorizedMints() public {
        vm.prank(CONTRIBUTOR_ACCOUNT); // Unauthorized user
        vm.expectRevert(EntityToken.EntityToken__UnauthorizedUser.selector);
        entityToken.safeMint(CONTRIBUTOR_ACCOUNT, DUMMY_HASH, Base64.encode(bytes(TOKEN_URI)));
    }

    function test_GetTokenIdByHash() public {
        vm.prank(address(entityManager));
        entityToken.safeMint(CONTRIBUTOR_ACCOUNT, DUMMY_HASH, Base64.encode(bytes(TOKEN_URI)));

        vm.prank(address(entityManager));
        uint256 tokenId = entityToken.getTokenIdByHash(DUMMY_HASH);
        assertEq(tokenId, 1);
    }

    function test_RevertIf_GetTokenIdForNonExistentHash() public {
        vm.prank(address(entityManager));
        vm.expectRevert(EntityToken.EntityToken__TokenIdNotFound.selector);
        entityToken.getTokenIdByHash(DUMMY_HASH);
    }

    function test_RevertIf_UnauthorizedGetsTokenIdByHash() public {
        // Arrange: Mint a token so there's a hash to look up
        vm.prank(address(entityManager));
        entityToken.safeMint(CONTRIBUTOR_ACCOUNT, DUMMY_HASH, Base64.encode(bytes(TOKEN_URI)));

        // Act & Assert: Unauthorized user tries to get the token ID and fails
        vm.prank(CONTRIBUTOR_ACCOUNT);
        vm.expectRevert(EntityToken.EntityToken__UnauthorizedUser.selector);
        entityToken.getTokenIdByHash(DUMMY_HASH);
    }
}

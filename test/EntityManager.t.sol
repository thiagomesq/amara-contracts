// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {TestBase} from "./TestBase.sol";
import {EntityManager} from "../src/EntityManager.sol";
import {OrganizationManager} from "../src/OrganizationManager.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";

contract EntityManagerTest is TestBase {
    string private constant ORG_NAME = "Test Org";
    string private constant ENTITY_NAME = "Test Entity";
    string private constant ENTITY_METADATA = "ipfs://some-hash";
    bytes32 private s_entityHash;

    function setUp() public override {
        super.setUp();
        // Approve the organization first
        vm.prank(ORG_ACCOUNT);
        organizationManager.registerOrganization(ORG_NAME);
        vm.prank(OWNER);
        organizationManager.setOrganizationStatus(ORG_ACCOUNT, OrganizationManager.OrganizationStatus.APPROVED);

        s_entityHash = keccak256(abi.encodePacked(ENTITY_NAME, ORG_ACCOUNT));
    }

    function test_RegisterEntity() public {
        vm.prank(ORG_ACCOUNT);
        entityManager.registerEntity(ENTITY_METADATA, s_entityHash);

        assertTrue(entityManager.isRegisteredEntity(1));
        assertEq(entityManager.getEntityHash(1), s_entityHash);
        assertEq(entityManager.getEntityMetadata(1), ENTITY_METADATA);
    }

    function test_RevertIf_UnapprovedOrgRegistersEntity() public {
        address unapprovedOrg = makeAddr("unapproved");
        vm.prank(unapprovedOrg);
        vm.expectRevert(EntityManager.EntityManager__OrganizationNotApproved.selector);
        entityManager.registerEntity(ENTITY_METADATA, s_entityHash);
    }

    function test_UpdateEntityMetadata() public {
        vm.prank(ORG_ACCOUNT);
        entityManager.registerEntity(ENTITY_METADATA, s_entityHash);

        string memory newMetadata = "ipfs://new-hash";
        vm.prank(ORG_ACCOUNT);
        entityManager.updateEntityMetadata(1, newMetadata);

        assertEq(entityManager.getEntityMetadata(1), newMetadata);
    }

    function test_RevertIf_OtherOrgUpdatesMetadata() public {
        // Arrange: Org 1 registers an entity
        vm.prank(ORG_ACCOUNT);
        entityManager.registerEntity(ENTITY_METADATA, s_entityHash);

        // Arrange: Create and approve a second organization
        address otherOrg = makeAddr("otherOrg");
        vm.prank(otherOrg);
        organizationManager.registerOrganization("Other Org");
        vm.prank(OWNER);
        organizationManager.setOrganizationStatus(otherOrg, OrganizationManager.OrganizationStatus.APPROVED);

        // Act & Assert: Other org tries to update metadata and fails
        string memory newMetadata = "ipfs://new-hash";
        vm.prank(otherOrg);
        vm.expectRevert(EntityManager.EntityManager__UnauthorizedUser.selector);
        entityManager.updateEntityMetadata(1, newMetadata);
    }

    function test_RevertIf_GetHashOfUnregisteredEntity() public {
        vm.expectRevert(EntityManager.EntityManager__EntityNotRegistered.selector);
        entityManager.getEntityHash(0);
    }

    function test_SetEntityToken_CanBeSetOnce() public {
        vm.prank(OWNER);
        vm.expectRevert(EntityManager.EntityManager__UnauthorizedUser.selector);
        entityManager.setEntityToken(address(entityToken)); // Already set in Deploy.s.sol
    }

    function test_MintEntityToken() public {
        // Arrange
        vm.prank(ORG_ACCOUNT);
        entityManager.registerEntity(Base64.encode(bytes(ENTITY_METADATA)), s_entityHash);

        // Act
        vm.prank(address(contribution));
        entityManager.mintEntityToken(CONTRIBUTOR_ACCOUNT, 1);

        // Assert
        assertEq(entityToken.ownerOf(1), CONTRIBUTOR_ACCOUNT);
        string memory tokenURI = entityToken.tokenURI(1);
        string memory expectedURI = string(abi.encodePacked("data:application/json;base64,", Base64.encode(bytes(ENTITY_METADATA))));
        assertEq(tokenURI, expectedURI);
    }
}

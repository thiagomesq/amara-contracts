// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console} from "forge-std/Test.sol";
import {EntityManager} from "../src/EntityManager.sol";
import {EntityToken} from "../src/EntityToken.sol";
import {Contribution} from "../src/Contribution.sol";
import {OrganizationManager} from "../src/OrganizationManager.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";

contract EntityManagerTest is Test {
    OrganizationManager private organizationManager;
    EntityManager private entityManager;
    EntityToken private entityToken;
    Contribution private contribution;

    address private constant OWNER = address(1);
    address private constant ORG_ACCOUNT = address(2);
    address private constant USER_ACCOUNT = address(3);

    string private constant ENTITY_METADATA = "ipfs://some-hash";
    bytes32 private s_entityHash;

    function setUp() public {
        // Deploy contracts
        vm.startPrank(OWNER);
        organizationManager = new OrganizationManager();
        entityManager = new EntityManager(address(organizationManager));
        entityToken = new EntityToken(address(entityManager));
        contribution = new Contribution(address(organizationManager), address(entityManager));

        // Set contract addresses
        entityManager.setContributionContract(address(contribution));
        entityManager.setEntityToken(address(entityToken));
        vm.stopPrank();

        // Register and approve organization
        vm.prank(ORG_ACCOUNT);
        organizationManager.registerOrganization("Org Name");

        vm.prank(OWNER);
        organizationManager.setActive(ORG_ACCOUNT);

        s_entityHash = keccak256(abi.encodePacked("some data"));
    }

    function test_RegisterEntity() public {
        vm.prank(ORG_ACCOUNT);
        entityManager.registerEntity(ENTITY_METADATA, s_entityHash);

        // Check if entity is registered
        assertTrue(entityManager.isRegisteredEntity(1));
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

    function test_RevertIf_UpdateUnregisteredEntity() public {
        vm.prank(ORG_ACCOUNT);
        vm.expectRevert(EntityManager.EntityManager__EntityNotRegistered.selector);
        entityManager.updateEntityMetadata(1, "new metadata");
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
        organizationManager.setActive(otherOrg);

        // Act & Assert: Other org tries to update metadata
        string memory newMetadata = "ipfs://new-hash";
        vm.prank(otherOrg);
        vm.expectRevert(EntityManager.EntityManager__UnauthorizedUser.selector);
        entityManager.updateEntityMetadata(1, newMetadata);
    }

    function test_RevertIf_UpdateByNonOrg() public {
        vm.prank(ORG_ACCOUNT);
        entityManager.registerEntity(ENTITY_METADATA, s_entityHash);

        string memory newMetadata = "ipfs://new-hash";
        vm.prank(USER_ACCOUNT);
        vm.expectRevert(EntityManager.EntityManager__UnauthorizedUser.selector);
        entityManager.updateEntityMetadata(1, newMetadata);
    }

    function test_MintEntityToken() public {
        // Arrange
        vm.prank(ORG_ACCOUNT);
        entityManager.registerEntity(Base64.encode(bytes(ENTITY_METADATA)), s_entityHash);

        // Act
        vm.prank(address(contribution));
        entityManager.mintEntityToken(USER_ACCOUNT, 1);

        // Assert
        assertEq(entityToken.ownerOf(1), USER_ACCOUNT);
        string memory tokenURI = entityToken.tokenURI(1);
        string memory expectedURI =
            string(abi.encodePacked("data:application/json;base64,", Base64.encode(bytes(ENTITY_METADATA))));
        assertEq(tokenURI, expectedURI);
    }

    function test_UpdateEntityMetadata_AlsoUpdatesTokenURI() public {
        // Arrange: Register entity and mint token
        vm.prank(ORG_ACCOUNT);
        entityManager.registerEntity(Base64.encode(bytes(ENTITY_METADATA)), s_entityHash);
        vm.prank(address(contribution));
        entityManager.mintEntityToken(USER_ACCOUNT, 1);

        // Act: Update metadata
        string memory newMetadata = Base64.encode(bytes("new metadata"));
        vm.prank(ORG_ACCOUNT);
        entityManager.updateEntityMetadata(1, newMetadata);

        // Assert: Token URI is updated
        string memory tokenURI = entityToken.tokenURI(1);
        string memory expectedURI = string(abi.encodePacked("data:application/json;base64,", newMetadata));
        assertEq(tokenURI, expectedURI);
    }

    function test_GetEntitiesByOrganization() public {
        // Arrange: Register 2 entities with ORG_ACCOUNT
        vm.prank(ORG_ACCOUNT);
        entityManager.registerEntity("ipfs://1", keccak256("one")); // ID 1
        vm.prank(ORG_ACCOUNT);
        entityManager.registerEntity("ipfs://2", keccak256("two")); // ID 2

        // Arrange: Register 1 entity with another org
        address otherOrg = makeAddr("otherOrg");
        vm.prank(otherOrg);
        organizationManager.registerOrganization("Other Org");
        vm.prank(OWNER);
        organizationManager.setActive(otherOrg);
        vm.prank(otherOrg);
        entityManager.registerEntity("ipfs://3", keccak256("three")); // ID 3

        // Act & Assert for ORG_ACCOUNT
        uint256[] memory orgEntities = entityManager.getEntitiesByOrganization(ORG_ACCOUNT);
        assertEq(orgEntities.length, 2);
        assertEq(orgEntities[0], 1);
        assertEq(orgEntities[1], 2);

        // Act & Assert for otherOrg
        uint256[] memory otherOrgEntities = entityManager.getEntitiesByOrganization(otherOrg);
        assertEq(otherOrgEntities.length, 1);
        assertEq(otherOrgEntities[0], 3);

        // Act & Assert for an org with no entities
        uint256[] memory noEntities = entityManager.getEntitiesByOrganization(makeAddr("no-entities"));
        assertEq(noEntities.length, 0);
    }
}
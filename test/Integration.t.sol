// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {TestBase} from "./TestBase.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import {OrganizationManager} from "../src/OrganizationManager.sol";

contract IntegrationTest is TestBase {
    string private constant ORG_NAME = "Happy Kids Foundation";
    string private constant ENTITY_NAME = "Child Sponsorship";
    string private constant ENTITY_METADATA = "ipfs://child-sponsorship-program";
    uint256 private constant CONTRIBUTION_AMOUNT = 1 ether;
    uint256 private constant SUB_INTERVAL = 30 days;

    function test_FullWorkflow() public {
        // 1. Organization registers
        vm.prank(ORG_ACCOUNT);
        organizationManager.registerOrganization(ORG_NAME);

        // 2. Owner approves organization
        vm.prank(OWNER);
        organizationManager.setOrganizationStatus(ORG_ACCOUNT, OrganizationManager.OrganizationStatus.APPROVED);
        assertTrue(organizationManager.isApprovedOrganization(ORG_ACCOUNT));

        // 3. Organization registers an entity
        vm.prank(ORG_ACCOUNT);
        entityManager.registerEntity(Base64.encode(bytes(ENTITY_METADATA)), keccak256(abi.encodePacked(ENTITY_NAME, ORG_ACCOUNT)));
        assertTrue(entityManager.isRegisteredEntity(1));

        // 4. Contributor makes a contribution
        vm.deal(CONTRIBUTOR_ACCOUNT, CONTRIBUTION_AMOUNT);
        uint256 orgInitialBalance = address(ORG_ACCOUNT).balance;

        vm.prank(CONTRIBUTOR_ACCOUNT);
        contribution.subscribe{value: CONTRIBUTION_AMOUNT}(ORG_ACCOUNT, 1, SUB_INTERVAL);

        // Verify results
        // Contributor received the NFT
        assertEq(entityToken.ownerOf(1), CONTRIBUTOR_ACCOUNT);

        // Organization received the funds
        uint256 orgFinalBalance = address(ORG_ACCOUNT).balance;
        assertEq(orgFinalBalance, orgInitialBalance + CONTRIBUTION_AMOUNT);

        // Verify token URI
        bytes32 expectedHash = keccak256(abi.encodePacked(ENTITY_NAME, ORG_ACCOUNT));
        string memory expectedUri = string(abi.encodePacked("data:application/json;base64,", Base64.encode(bytes(ENTITY_METADATA))));
        vm.prank(address(entityManager));
        uint256 tokenId = entityToken.getTokenIdByHash(expectedHash);
        assertEq(entityToken.tokenURI(1), expectedUri);
        assertEq(tokenId, 1);
    }
}

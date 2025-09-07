// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {TestBase} from "./TestBase.sol";
import {Contribution} from "../src/Contribution.sol";
import {EntityManager} from "../src/EntityManager.sol";
import {OrganizationManager} from "../src/OrganizationManager.sol";

contract ContributionTest is TestBase {
    string private constant ORG_NAME = "Test Org";
    string private constant ENTITY_NAME = "Test Entity";
    string private constant ENTITY_METADATA = "ipfs://some-hash";
    uint256 private constant CONTRIBUTION_AMOUNT = 1 ether;
    uint256 private constant SUB_INTERVAL = 30 days;
    uint256 private s_entityId;

    function setUp() public override {
        super.setUp();
        // Pre-approve organization and register an entity
        vm.prank(ORG_ACCOUNT);
        organizationManager.registerOrganization(ORG_NAME);
        vm.prank(OWNER);
        organizationManager.setOrganizationStatus(ORG_ACCOUNT, OrganizationManager.OrganizationStatus.APPROVED);

        vm.prank(ORG_ACCOUNT);
        bytes32 entityHash = keccak256(abi.encodePacked(ENTITY_NAME, ORG_ACCOUNT));
        entityManager.registerEntity(ENTITY_METADATA, entityHash);
        s_entityId = 1;
    }

    // --- Subscription Tests ---

    function test_Subscribe() public {
        vm.deal(CONTRIBUTOR_ACCOUNT, CONTRIBUTION_AMOUNT);
        uint256 orgInitialBalance = address(ORG_ACCOUNT).balance;

        vm.prank(CONTRIBUTOR_ACCOUNT);
        vm.expectEmit(true, true, true, true);
        emit Contribution.Subscribed(CONTRIBUTOR_ACCOUNT, s_entityId, CONTRIBUTION_AMOUNT, SUB_INTERVAL);
        contribution.subscribe{value: CONTRIBUTION_AMOUNT}(ORG_ACCOUNT, s_entityId, SUB_INTERVAL);

        assertEq(entityToken.ownerOf(1), CONTRIBUTOR_ACCOUNT);
        assertEq(address(ORG_ACCOUNT).balance, orgInitialBalance + CONTRIBUTION_AMOUNT);
    }

    function test_RevertIf_SubscribeToActiveSubscription() public {
        // First subscription
        vm.deal(CONTRIBUTOR_ACCOUNT, CONTRIBUTION_AMOUNT * 2);
        vm.prank(CONTRIBUTOR_ACCOUNT);
        contribution.subscribe{value: CONTRIBUTION_AMOUNT}(ORG_ACCOUNT, s_entityId, SUB_INTERVAL);

        // Attempt to subscribe again
        vm.prank(CONTRIBUTOR_ACCOUNT);
        vm.expectRevert(Contribution.Contribution__SubscriptionAlreadyExists.selector);
        contribution.subscribe{value: CONTRIBUTION_AMOUNT}(ORG_ACCOUNT, s_entityId, SUB_INTERVAL);
    }

    function test_RenewSubscription() public {
        // Subscribe first
        vm.deal(CONTRIBUTOR_ACCOUNT, CONTRIBUTION_AMOUNT * 2);
        vm.prank(CONTRIBUTOR_ACCOUNT);
        contribution.subscribe{value: CONTRIBUTION_AMOUNT}(ORG_ACCOUNT, s_entityId, SUB_INTERVAL);

        uint256 orgBalanceAfterSub = address(ORG_ACCOUNT).balance;

        // Fast-forward time
        uint256 expectedTimestamp = block.timestamp + SUB_INTERVAL + 1;
        vm.warp(expectedTimestamp);

        // Renew
        vm.prank(CONTRIBUTOR_ACCOUNT);
        vm.expectEmit(true, true, false, true);
        emit Contribution.SubscriptionRenewed(CONTRIBUTOR_ACCOUNT, s_entityId, expectedTimestamp);
        contribution.renewSubscription{value: CONTRIBUTION_AMOUNT}(s_entityId);

        assertEq(address(ORG_ACCOUNT).balance, orgBalanceAfterSub + CONTRIBUTION_AMOUNT);
    }

    function test_RevertIf_RenewTooEarly() public {
        vm.deal(CONTRIBUTOR_ACCOUNT, CONTRIBUTION_AMOUNT);
        vm.prank(CONTRIBUTOR_ACCOUNT);
        contribution.subscribe{value: CONTRIBUTION_AMOUNT}(ORG_ACCOUNT, s_entityId, SUB_INTERVAL);

        // Don't fast-forward time
        vm.deal(CONTRIBUTOR_ACCOUNT, CONTRIBUTION_AMOUNT);
        vm.prank(CONTRIBUTOR_ACCOUNT);
        vm.expectRevert(Contribution.Contribution__SubscriptionNotDue.selector);
        contribution.renewSubscription{value: CONTRIBUTION_AMOUNT}(s_entityId);
    }

    function test_RevertIf_RenewWithWrongAmount() public {
        vm.deal(CONTRIBUTOR_ACCOUNT, CONTRIBUTION_AMOUNT + 1 wei);
        vm.prank(CONTRIBUTOR_ACCOUNT);
        contribution.subscribe{value: CONTRIBUTION_AMOUNT}(ORG_ACCOUNT, s_entityId, SUB_INTERVAL);

        vm.warp(block.timestamp + SUB_INTERVAL + 1);

        vm.prank(CONTRIBUTOR_ACCOUNT);
        vm.expectRevert(Contribution.Contribution__InvalidContributionAmount.selector);
        contribution.renewSubscription{value: 1 wei}(s_entityId);
    }

    function test_CancelSubscription() public {
        vm.deal(CONTRIBUTOR_ACCOUNT, CONTRIBUTION_AMOUNT);
        vm.prank(CONTRIBUTOR_ACCOUNT);
        contribution.subscribe{value: CONTRIBUTION_AMOUNT}(ORG_ACCOUNT, s_entityId, SUB_INTERVAL);

        vm.prank(CONTRIBUTOR_ACCOUNT);
        vm.expectEmit(true, true, false, true);
        emit Contribution.SubscriptionCanceled(CONTRIBUTOR_ACCOUNT, s_entityId);
        contribution.cancelSubscription(s_entityId);

        // Verify it's cancelled
        vm.warp(block.timestamp + SUB_INTERVAL + 1);
        vm.deal(CONTRIBUTOR_ACCOUNT, CONTRIBUTION_AMOUNT);
        vm.prank(CONTRIBUTOR_ACCOUNT);
        vm.expectRevert(Contribution.Contribution__SubscriptionNotFound.selector);
        contribution.renewSubscription{value: CONTRIBUTION_AMOUNT}(s_entityId);
    }
}

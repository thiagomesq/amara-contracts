// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {OrganizationManager} from "./OrganizationManager.sol";
import {EntityManager} from "./EntityManager.sol";

/**
 * @title Contribution
 * @author Thiago Mesquita
 * @notice Handles contributions to organizations for sponsoring entities.
 */
contract Contribution is Ownable, ReentrancyGuard {
    // Custom Errors
    error Contribution__InvalidContributionAmount();
    error Contribution__TransferFailed();
    error Contribution__InvalidOrganization();
    error Contribution__NotAnApprovedOrganization();
    error Contribution__EntityNotRegistered();
    error Contribution__SubscriptionAlreadyExists();
    error Contribution__SubscriptionNotFound();
    error Contribution__SubscriptionNotDue();

    // Structs
    struct Subscription {
        address contributor;
        address organization;
        uint256 entityId;
        uint256 amount;
        uint256 interval; // e.g., 30 days
        uint256 lastPaymentTimestamp;
        bool isActive;
    }

    // State Variables
    OrganizationManager private immutable i_organizationManager;
    EntityManager private immutable i_entityManager;

    // Mappings
    mapping(address => mapping(uint256 => Subscription)) private s_subscriptions;

    // Events
    event Contributed(address indexed contributor, address indexed orgAddress, uint256 amount);
    event Subscribed(address indexed contributor, uint256 indexed entityId, uint256 amount, uint256 interval);
    event SubscriptionRenewed(address indexed contributor, uint256 indexed entityId, uint256 newPaymentTimestamp);
    event SubscriptionCanceled(address indexed contributor, uint256 indexed entityId);

    modifier onlyRegisteredEntity(uint256 entityId) {
        if (!i_entityManager.isRegisteredEntity(entityId)) {
            revert Contribution__EntityNotRegistered();
        }
        _;
    }

    modifier onlyEnoughValue() {
        if (msg.value == 0) {
            revert Contribution__InvalidContributionAmount();
        }
        _;
    }

    /**
     * @param orgManagerAddress The address of the OrganizationManager contract.
     * @param entityManagerAddress The address of the EntityManager contract.
     */
    constructor(
        address orgManagerAddress,
        address entityManagerAddress
    ) Ownable(msg.sender) {
        i_organizationManager = OrganizationManager(orgManagerAddress);
        i_entityManager = EntityManager(entityManagerAddress);
    }

    function contribute(address orgAddress) external payable nonReentrant onlyEnoughValue {
        if (orgAddress == address(0)) {
            revert Contribution__InvalidOrganization();
        }
        if (!i_organizationManager.isApprovedOrganization(orgAddress)) {
            revert Contribution__NotAnApprovedOrganization();
        }

        _transferToOrg(orgAddress, msg.value);

        emit Contributed(msg.sender, orgAddress, msg.value);
    }

    /**
     * @notice Allows a user to subscribe for recurring contributions to an entity.
     * @param orgAddress The address of the organization.
     * @param entityId The ID of the entity to sponsor.
     * @param interval The desired interval between payments, in seconds (e.g., 30 days).
     */
    function subscribe(address orgAddress, uint256 entityId, uint256 interval) external payable nonReentrant onlyEnoughValue {
        if (s_subscriptions[msg.sender][entityId].isActive) {
            revert Contribution__SubscriptionAlreadyExists();
        }
        _validateContribution(orgAddress, entityId);

        s_subscriptions[msg.sender][entityId] = Subscription({
            contributor: msg.sender,
            organization: orgAddress,
            entityId: entityId,
            amount: msg.value,
            interval: interval,
            lastPaymentTimestamp: block.timestamp,
            isActive: true
        });

        i_entityManager.mintEntityToken(msg.sender, entityId);

        _transferToOrg(orgAddress, msg.value);

        emit Subscribed(msg.sender, entityId, msg.value, interval);
    }

    /**
     * @notice Renews an existing subscription if the payment is due.
     * @param entityId The ID of the entity for which to renew the subscription.
     */
    function renewSubscription(uint256 entityId) external payable nonReentrant onlyRegisteredEntity(entityId) {
        Subscription storage subscription = s_subscriptions[msg.sender][entityId];
        
        if (!subscription.isActive) {
            revert Contribution__SubscriptionNotFound();
        }
        
        if (block.timestamp < subscription.lastPaymentTimestamp + subscription.interval) {
            revert Contribution__SubscriptionNotDue();
        }
        
        if (msg.value != subscription.amount) {
            revert Contribution__InvalidContributionAmount();
        }
        
        // Update the last payment timestamp
        subscription.lastPaymentTimestamp = block.timestamp;

        // Transfer the funds to the organization
        _transferToOrg(subscription.organization, msg.value);
        
        emit SubscriptionRenewed(msg.sender, entityId, subscription.lastPaymentTimestamp);
    }

    /**
     * @notice Cancels an active subscription.
     * @param entityId The ID of the entity for which to cancel the subscription.
     */
    function cancelSubscription(uint256 entityId) external nonReentrant onlyRegisteredEntity(entityId) {
        Subscription storage subscription = s_subscriptions[msg.sender][entityId];
        
        if (!subscription.isActive) {
            revert Contribution__SubscriptionNotFound();
        }
        
        subscription.isActive = false;
        emit SubscriptionCanceled(msg.sender, entityId);
    }

    /**
     * @notice Validates the contribution parameters.
     * @param orgAddress The address of the organization.
     * @param entityId The ID of the entity.
     */
    function _validateContribution(address orgAddress, uint256 entityId) private view {
        if (orgAddress == address(0)) {
            revert Contribution__InvalidOrganization();
        }
        if (!i_organizationManager.isApprovedOrganization(orgAddress)) {
            revert Contribution__NotAnApprovedOrganization();
        }
        if (!i_entityManager.isRegisteredEntity(entityId)) {
            revert Contribution__EntityNotRegistered();
        }
    }

    /**
     * @notice Transfers the specified amount to the organization.
     * @param orgAddress The address of the organization.
     * @param amount The amount to transfer.
     */
    function _transferToOrg(address orgAddress, uint256 amount) private {
        (bool success, ) = orgAddress.call{value: amount}("");
        if (!success) {
            revert Contribution__TransferFailed();
        }
    }
}

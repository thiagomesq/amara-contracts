// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IRegistry} from "./interfaces/IRegistry.sol";
import {OrganizationManager} from "./OrganizationManager.sol";
import {EntityManager} from "./EntityManager.sol";

/**
 * @title Contribution
 * @author Thiago Mesquita
 * @notice Handles contributions to organizations for sponsoring entities.
 */
// aderyn-fp-next-line(contract-locks-ether)
contract Contribution is AccessControlUpgradeable, ReentrancyGuardUpgradeable, UUPSUpgradeable {
    using SafeERC20 for IERC20;

    // Custom Errors
    error Contribution__InvalidContributionAmount();
    error Contribution__InvalidOrganization();
    error Contribution__NotAnApprovedOrganization();
    error Contribution__EntityNotRegistered();
    error Contribution__SubscriptionAlreadyExists();
    error Contribution__SubscriptionNotFound();
    error Contribution__SubscriptionNotDue();
    error Contribution__InvalidServiceFee();
    error Contribution__ZeroAddressNotAllowed();

    // Structs
    struct Subscription {
        address contributor;
        address organization;
        address token;
        uint256 entityId;
        uint256 amount;
        uint256 interval; // e.g., 30 days
        uint256 lastPaymentTimestamp;
        bool isActive;
    }

    // State Variables
    uint8 private constant MAX_SERVICE_FEE = 100;
    address private s_registry;
    uint8 private s_serviceFee = 0;

    // Mappings
    mapping(address => mapping(uint256 => Subscription)) private s_subscriptions;

    // Events
    event Contributed(address indexed contributor, address indexed orgAddress, address indexed token, uint256 amount);
    event Subscribed(
        address indexed contributor, uint256 indexed entityId, address indexed token, uint256 amount, uint256 interval
    );
    event SubscriptionRenewed(address indexed contributor, uint256 indexed entityId, uint256 newPaymentTimestamp);
    event SubscriptionCanceled(address indexed contributor, uint256 indexed entityId);
    event ServiceFeeSet(uint8 serviceFee);

    modifier onlyEnoughAmount(uint256 amount) {
        if (amount == 0) {
            revert Contribution__InvalidContributionAmount();
        }
        _;
    }

    modifier onlyRegisteredEntity(uint256 entityId) {
        address entityManagerAddress = _getEntityManagerAddress();
        if (!EntityManager(payable(entityManagerAddress)).isRegisteredEntity(entityId)) {
            revert Contribution__EntityNotRegistered();
        }
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    receive() external payable {
        revert();
    }

    function initialize(address registryAddress, address admin) external initializer {
        if (admin == address(0) || registryAddress == address(0)) {
            revert Contribution__ZeroAddressNotAllowed();
        }
        __AccessControl_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        s_registry = registryAddress;
    }

    function setServiceFee(uint8 serviceFee) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (serviceFee == s_serviceFee) return;
        if (serviceFee > MAX_SERVICE_FEE) revert Contribution__InvalidServiceFee();
        s_serviceFee = serviceFee;
        emit ServiceFeeSet(serviceFee);
    }

    function getServiceFee() external view returns (uint8) {
        return s_serviceFee;
    }

    function withdrawFees(address token) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 balance = IERC20(token).balanceOf(address(this));
        if (balance > 0) {
            IERC20(token).safeTransfer(_msgSender(), balance);
        }
    }

    /**
     * @notice Allows a user to approve and contribute tokens in a single conceptual step.
     * @dev The user must first approve this contract to spend tokens on their behalf.
     * @param orgAddress The address of the organization.
     * @param token The address of the ERC20 token.
     * @param amount The amount of tokens to contribute.
     * @param deadline The deadline for the permit signature.
     * @param v The recovery id of the signature.
     * @param r The r value of the signature.
     * @param s The s value of the signature.
     */
    function depositAndContribute(
        address orgAddress,
        address token,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external nonReentrant onlyEnoughAmount(amount) {
        _permitAndTransfer(token, msg.sender, address(this), amount, deadline, v, r, s);

        if (orgAddress == address(0)) {
            revert Contribution__InvalidOrganization();
        }
        address orgManagerAddress = _getOrgManagerAddress();
        if (!OrganizationManager(payable(orgManagerAddress)).isApprovedOrganization(orgAddress)) {
            revert Contribution__NotAnApprovedOrganization();
        }

        _transferToOrg(orgAddress, token, amount);

        emit Contributed(msg.sender, orgAddress, token, amount);
    }

    /**
     * @notice Allows a user to subscribe for recurring contributions to an entity.
     * @param orgAddress The address of the organization.
     * @param entityId The ID of the entity to sponsor.
     * @param token The address of the ERC20 token to be used for payment.
     * @param amount The amount of tokens for each payment.
     * @param interval The desired interval between payments, in seconds (e.g., 30 days).
     * @param deadline The deadline for the permit signature.
     * @param v The recovery id of the signature.
     * @param r The r value of the signature.
     * @param s The s value of the signature.
     */
    function subscribe(
        address orgAddress,
        uint256 entityId,
        address token,
        uint256 amount,
        uint256 interval,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external nonReentrant onlyEnoughAmount(amount) {
        if (s_subscriptions[msg.sender][entityId].isActive) {
            revert Contribution__SubscriptionAlreadyExists();
        }
        _validateContribution(orgAddress, entityId);

        s_subscriptions[msg.sender][entityId] = Subscription({
            contributor: msg.sender,
            organization: orgAddress,
            token: token,
            entityId: entityId,
            amount: amount,
            interval: interval,
            lastPaymentTimestamp: block.timestamp,
            isActive: true
        });

        _permitAndTransfer(token, msg.sender, address(this), amount, deadline, v, r, s);

        address entityManagerAddress = _getEntityManagerAddress();
        EntityManager(payable(entityManagerAddress)).mintEntityToken(msg.sender, entityId);

        _transferToOrg(orgAddress, token, amount);

        emit Subscribed(msg.sender, entityId, token, amount, interval);
    }

    /**
     * @notice Renews an existing subscription if the payment is due.
     * @param entityId The ID of the entity for which to renew the subscription.
     * @param deadline The deadline for the permit signature.
     * @param v The recovery id of the signature.
     * @param r The r value of the signature.
     * @param s The s value of the signature.
     */
    // aderyn-ignore-next-line(eth-send-unchecked-address)
    function renewSubscription(uint256 entityId, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        external
        nonReentrant
        onlyRegisteredEntity(entityId)
    {
        Subscription storage subscription = s_subscriptions[msg.sender][entityId];

        if (!subscription.isActive) {
            revert Contribution__SubscriptionNotFound();
        }

        if (block.timestamp < subscription.lastPaymentTimestamp + subscription.interval) {
            revert Contribution__SubscriptionNotDue();
        }

        // Update the last payment timestamp BEFORE the transfer to prevent re-entrancy issues
        subscription.lastPaymentTimestamp = block.timestamp;

        _permitAndTransfer(subscription.token, msg.sender, address(this), subscription.amount, deadline, v, r, s);

        // Transfer the funds to the organization
        _transferToOrg(subscription.organization, subscription.token, subscription.amount);

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
        address orgManagerAddress = _getOrgManagerAddress();
        if (!OrganizationManager(payable(orgManagerAddress)).isApprovedOrganization(orgAddress)) {
            revert Contribution__NotAnApprovedOrganization();
        }
        address entityManagerAddress = _getEntityManagerAddress();
        if (!EntityManager(payable(entityManagerAddress)).isRegisteredEntity(entityId)) {
            revert Contribution__EntityNotRegistered();
        }
    }

    /**
     * @notice Transfers the specified amount to the organization.
     * @param orgAddress The address of the organization.
     * @param token The address of the ERC20 token.
     * @param amount The amount to transfer.
     */
    function _transferToOrg(address orgAddress, address token, uint256 amount) private {
        uint256 serviceFeeAmount = (amount * s_serviceFee) / 100;
        if (serviceFeeAmount > 0) {
            IERC20(token).safeTransfer(address(this), serviceFeeAmount);
        }
        IERC20(token).safeTransfer(orgAddress, amount - serviceFeeAmount);
    }

    /**
     * @notice Allows a user to approve and transfer tokens in a single conceptual step.
     */
    function _permitAndTransfer(
        address token,
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal {
        IERC20Permit(token).permit(owner, spender, value, deadline, v, r, s);
        IERC20(token).safeTransferFrom(owner, address(this), value);
    }

    function _getOrgManagerAddress() internal view returns (address) {
        return IRegistry(s_registry).getAddress(keccak256("ORGANIZATION_MANAGER"));
    }

    function _getEntityManagerAddress() internal view returns (address) {
        return IRegistry(s_registry).getAddress(keccak256("ENTITY_MANAGER"));
    }

    function _authorizeUpgrade(address newImplementation) internal view override onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newImplementation == address(0)) {
            revert Contribution__ZeroAddressNotAllowed();
        }
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title OrganizationManager
 * @author Thiago Mesquita
 * @notice Manages the registration and approval of organizations.
 */
// aderyn-fp-next-line(contract-locks-ether)
contract OrganizationManager is AccessControlUpgradeable, ReentrancyGuardUpgradeable, UUPSUpgradeable {
    // Custom Errors
    error OrganizationManager__OrganizationAlreadyExists();
    error OrganizationManager__OrganizationNotRegistered();
    error OrganizationManager__AddressAlreadyLinked();
    error OrganizationManager__NotOrganizationOwner();
    error OrganizationManager__ZeroAddressNotAllowed();

    // Structs
    struct Organization {
        bytes32 orgHash; // The canonical, permanent identifier
        address owner; // The current controlling address
        string name;
    }

    // State Variables
    bytes32[] private s_organizationHashes;
    mapping(bytes32 => Organization) private s_organizations;
    mapping(bytes32 => bool) private s_approvedOrganizations;
    mapping(address => bytes32) private s_addressToOrgHash;
    mapping(bytes32 => bool) private s_isOrgHashRegistered;

    // Events
    event OrganizationRegistered(bytes32 indexed orgHash, address indexed owner, string name);
    event OrganizationApproved(bytes32 indexed orgHash);
    event OrganizationOwnerUpdated(bytes32 indexed orgHash, address indexed newOwner);

    // Modifiers
    modifier isOrganization(bytes32 orgHash) {
        if (!s_isOrgHashRegistered[orgHash]) {
            revert OrganizationManager__OrganizationNotRegistered();
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

    function initialize(address admin) external initializer {
        if (admin == address(0)) {
            revert OrganizationManager__ZeroAddressNotAllowed();
        }
        __AccessControl_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    /**
     * @notice Registers a new organization.
     * @param orgHash A unique hash representing the organization's off-chain data.
     * @param name The name of the organization.
     */
    function registerOrganization(bytes32 orgHash, string calldata name) external nonReentrant {
        if (s_isOrgHashRegistered[orgHash]) {
            revert OrganizationManager__OrganizationAlreadyExists();
        }
        if (s_addressToOrgHash[msg.sender] != bytes32(0)) {
            revert OrganizationManager__AddressAlreadyLinked();
        }

        s_organizations[orgHash] = Organization({orgHash: orgHash, owner: msg.sender, name: name});
        s_addressToOrgHash[msg.sender] = orgHash;
        s_isOrgHashRegistered[orgHash] = true;
        s_organizationHashes.push(orgHash);

        emit OrganizationRegistered(orgHash, msg.sender, name);
    }

    /**
     * @notice Approves an organization, allowing it to register entities.
     * @param orgHash The hash of the organization to approve.
     */
    function approveOrganization(bytes32 orgHash) external onlyRole(DEFAULT_ADMIN_ROLE) isOrganization(orgHash) {
        s_approvedOrganizations[orgHash] = true;
        emit OrganizationApproved(orgHash);
    }

    /**
     * @notice Updates the controlling address of an organization.
     * @param orgHash The hash of the organization.
     * @param newOwner The new controlling address.
     */
    function updateOrganizationOwner(bytes32 orgHash, address newOwner) external nonReentrant {
        if (newOwner == address(0)) {
            revert OrganizationManager__ZeroAddressNotAllowed();
        }
        Organization storage org = s_organizations[orgHash];
        if (org.owner != msg.sender) {
            revert OrganizationManager__NotOrganizationOwner();
        }
        if (s_addressToOrgHash[newOwner] != bytes32(0)) {
            revert OrganizationManager__AddressAlreadyLinked();
        }

        delete s_addressToOrgHash[org.owner];
        s_addressToOrgHash[newOwner] = orgHash;
        org.owner = newOwner;

        emit OrganizationOwnerUpdated(orgHash, newOwner);
    }

    /**
     * @notice Checks if an address belongs to an approved organization.
     * @param orgAddress The address to check.
     * @return True if the address belongs to an approved organization, false otherwise.
     */
    function isApprovedOrganization(address orgAddress) external view returns (bool) {
        bytes32 orgHash = s_addressToOrgHash[orgAddress];
        if (orgHash == bytes32(0)) {
            return false;
        }
        return s_approvedOrganizations[orgHash];
    }

    /**
     * @notice Retrieves organization details by its hash.
     * @param orgHash The hash of the organization.
     * @return The organization's data.
     */
    function getOrganization(bytes32 orgHash) external view isOrganization(orgHash) returns (Organization memory) {
        return s_organizations[orgHash];
    }

    /**
     * @notice Retrieves all registered organization hashes.
     * @return An array of organization hashes.
     */
    function getOrganizationsHashes() external view returns (bytes32[] memory) {
        return s_organizationHashes;
    }

    /**
     * @notice Retrieves the organization hash associated with an address.
     * @param ownerAddress The address of the organization's owner.
     * @return The organization's hash.
     */
    function getOrgHashByOwner(address ownerAddress) external view returns (bytes32) {
        bytes32 orgHash = s_addressToOrgHash[ownerAddress];
        if (!s_isOrgHashRegistered[orgHash]) {
            revert OrganizationManager__OrganizationNotRegistered();
        }
        return orgHash;
    }

    function _authorizeUpgrade(address newImplementation) internal view override onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newImplementation == address(0)) {
            revert OrganizationManager__ZeroAddressNotAllowed();
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title OrganizationManager
 * @author Thiago Mesquita
 * @notice Manages the registration and approval of organizations.
 */
contract OrganizationManager is Ownable, ReentrancyGuard {
    // Custom Errors
    error OrganizationManager__OrganizationAlreadyExists();
    error OrganizationManager__OrganizationNotExists();

    // Enums
    enum OrganizationStatus { PENDING, APPROVED, REJECTED }

    // Structs
    struct Organization {
        string name;
        OrganizationStatus status;
    }

    // State Variables
    mapping(address => Organization) public organizations;
    address[] public organizationAddresses;

    // Events
    event OrganizationRegistered(address indexed orgAddress, string name);
    event OrganizationStatusChanged(address indexed orgAddress, OrganizationStatus status);

    constructor() Ownable(msg.sender) {}

    /**
     * @notice Allows a new organization to register.
     * @param name The name of the organization.
     */
    function registerOrganization(string calldata name) external nonReentrant {
        if (bytes(organizations[msg.sender].name).length != 0) {
            revert OrganizationManager__OrganizationAlreadyExists();
        }

        organizations[msg.sender] = Organization({
            name: name,
            status: OrganizationStatus.PENDING
        });
        organizationAddresses.push(msg.sender);

        emit OrganizationRegistered(msg.sender, name);
    }

    /**
     * @notice Allows the owner to activate an organization.
     * @param orgAddress The address of the organization.
     */
    function setActive(address orgAddress) external onlyOwner {
        setOrganizationStatus(orgAddress, OrganizationStatus.APPROVED);
    }

    /**
     * @notice Allows the owner to change the status of an organization.
     * @param orgAddress The address of the organization.
     * @param status The new status for the organization.
     */
    function setOrganizationStatus(address orgAddress, OrganizationStatus status) public onlyOwner {
        if (bytes(organizations[orgAddress].name).length == 0) {
            revert OrganizationManager__OrganizationNotExists();
        }

        organizations[orgAddress].status = status;
        emit OrganizationStatusChanged(orgAddress, status);
    }

    /**
     * @notice Checks if an address belongs to an approved organization.
     * @param orgAddress The address to check.
     * @return True if the organization is approved, false otherwise.
     */
    function isApprovedOrganization(address orgAddress) external view returns (bool) {
        return organizations[orgAddress].status == OrganizationStatus.APPROVED;
    }

    /**
     * @notice Retrieves the details of an organization.
     * @param orgAddress The address of the organization.
     * @return The Organization struct.
     */
    function getOrganization(address orgAddress) external view returns (Organization memory) {
        if (bytes(organizations[orgAddress].name).length == 0) {
            revert OrganizationManager__OrganizationNotExists();
        }
        return organizations[orgAddress];
    }

    /**
     * @notice Retrieves the number of registered organizations.
     * @return The total count of organizations.
     */
    function getOrganizationCount() external view returns (uint256) {
        return organizationAddresses.length;
    }

    function getOrganizations() external view returns (address[] memory) {
        return organizationAddresses;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {OrganizationManager} from "./OrganizationManager.sol";
import {EntityToken} from "./EntityToken.sol";

/**
 * @title EntityManager
 * @author Thiago Mesquita
 * @notice Manages the registration of entities by approved organizations.
 */
contract EntityManager is Ownable, ReentrancyGuard {
    // Custom Errors
    error EntityManager__EntityNotRegistered();
    error EntityManager__UnauthorizedUser();
    error EntityManager__OrganizationNotApproved();
    error EntityManager__InvalidOrganizationManager();
    error EntityManager__InvalidEntityToken();

    // Structs
    struct Entity {
        uint256 id;
        address organization;
        bytes32 dataHash;
        string metadata;
    }

    // State Variables
    address private immutable i_organizationManager;
    address private s_contributionContract;
    address private s_entityToken;
    mapping(uint256 => Entity) private s_entities;
    mapping(address => uint256[]) private s_entitiesByOrganization;
    uint256 private s_nextTokenId = 1;

    // Events
    event EntityRegistered(uint256 indexed entityId, address indexed orgAddress, bytes32 dataHash);
    event EntityMetadataUpdated(uint256 indexed entityId, string metadata);
    event ContributionContractSet(address indexed contributionContract);
    event EntityTokenSet(address indexed entityToken);

    /**
     * @notice Modifier to ensure a function is called only by the Contribution contract.
     */
    modifier onlyContributionContract() {
        if (msg.sender != s_contributionContract) {
            revert EntityManager__UnauthorizedUser();
        }
        _;
    }

    /**
     * @param orgManagerAddress The address of the OrganizationManager contract.
     */
    constructor(address orgManagerAddress) Ownable(msg.sender) {
        if (orgManagerAddress == address(0)) {
            revert EntityManager__InvalidOrganizationManager();
        }
        i_organizationManager = orgManagerAddress;
    }

    /**
     * @notice Allows an approved organization to register a new entity.
     * @param metadata The metadata of the entity.
     * @param entityHash The hash of the entity data.
     */
    function registerEntity(string calldata metadata, bytes32 entityHash) external nonReentrant {
        if (!_isApprovedOrganization(msg.sender)) {
            revert EntityManager__OrganizationNotApproved();
        }

        uint256 entityId = s_nextTokenId++;

        s_entities[entityId] = Entity({
            id: entityId,
            organization: msg.sender,
            dataHash: entityHash,
            metadata: metadata
        });

        s_entitiesByOrganization[msg.sender].push(entityId);

        emit EntityRegistered(entityId, msg.sender, entityHash);
    }

    /**
     * @notice Updates the metadata of a registered entity.
     * @param entityId The ID of the entity.
     * @param newMetadata The new metadata for the entity.
     */
    function updateEntityMetadata(uint256 entityId, string calldata newMetadata) external nonReentrant {
        if (!isRegisteredEntity(entityId)) {
            revert EntityManager__EntityNotRegistered();
        }
        
        // Only the organization that registered the entity can update its metadata
        if (s_entities[entityId].organization != msg.sender) {
            revert EntityManager__UnauthorizedUser();
        }
        
        s_entities[entityId].metadata = newMetadata;
        emit EntityMetadataUpdated(entityId, newMetadata);
    }

    /**
     * @notice Mints a new token for a given entity and assigns it to the contributor.
     * @dev This function can only be called by the Contribution contract.
     * @param contributor The address of the user who contributed.
     * @param entityId The ID of the entity being sponsored.
     */
    function mintEntityToken(address contributor, uint256 entityId) external onlyContributionContract {
        if (!isRegisteredEntity(entityId)) {
            revert EntityManager__EntityNotRegistered();
        }

        bytes32 entityHash = getEntityHash(entityId);
        string memory metadata = getEntityMetadata(entityId);

        EntityToken(s_entityToken).safeMint(contributor, entityHash, metadata);
    }

    /**
     * @notice Allows the owner to set the address of the Contribution contract.
     * @param _contributionAddress The address of the Contribution contract.
     */
    function setContributionContract(address _contributionAddress) external onlyOwner {
        if (_contributionAddress == s_contributionContract) return;
        s_contributionContract = _contributionAddress;
        emit ContributionContractSet(_contributionAddress);
    }

    /**
     * @notice Allows the owner to set the address of the EntityToken contract.
     * @dev Can only be set once.
     * @param _entityTokenAddress The address of the EntityToken contract.
     */
    function setEntityToken(address _entityTokenAddress) external onlyOwner {
        if (_entityTokenAddress == address(0)) {
            revert EntityManager__InvalidEntityToken();
        }
        if (s_entityToken != address(0)) {
            revert EntityManager__UnauthorizedUser(); // Or a more specific error
        }
        s_entityToken = _entityTokenAddress;
        emit EntityTokenSet(_entityTokenAddress);
    }

    /**
     * @notice Retrieves the hash of a registered entity.
     * @param entityId The ID of the entity.
     * @return The hash of the entity.
     */
    function getEntityHash(uint256 entityId) public view returns (bytes32) {
        if (!isRegisteredEntity(entityId)) {
            revert EntityManager__EntityNotRegistered();
        }
        return s_entities[entityId].dataHash;
    }

    /**
     * @notice Retrieves the metadata of a registered entity.
     * @param entityId The ID of the entity.
     * @return The metadata of the entity.
     */
    function getEntityMetadata(uint256 entityId) public view returns (string memory) {
        return s_entities[entityId].metadata;
    }

    /**
     * @notice Retrieves all entity IDs for a given organization.
     * @param orgAddress The address of the organization.
     * @return An array of entity IDs.
     */
    function getEntitiesByOrganization(address orgAddress) external view returns (uint256[] memory) {
        return s_entitiesByOrganization[orgAddress];
    }

    /**
     * @notice Checks if an entity is registered.
     * @param entityId The ID of the entity.
     * @return True if the entity is registered, false otherwise.
     */
    function isRegisteredEntity(uint256 entityId) public view returns (bool) {
        return s_entities[entityId].organization != address(0);
    }
    
    /**
     * @notice Checks if an organization is approved.
     * @param orgAddress The address of the organization.
     * @return True if the organization is approved, false otherwise.
     */
    function _isApprovedOrganization(address orgAddress) internal view returns (bool) {
        return OrganizationManager(i_organizationManager).isApprovedOrganization(orgAddress);
    }
}

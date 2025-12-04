// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IRegistry} from "./interfaces/IRegistry.sol";
import {OrganizationManager} from "./OrganizationManager.sol";
import {EntityToken} from "./EntityToken.sol";
import {Structs} from "./libraries/Structs.sol";

/**
 * @title EntityManager
 * @author Thiago Mesquita
 * @notice Manages the registration of entities by approved organizations.
 */
// aderyn-fp-next-line(contract-locks-ether)
contract EntityManager is AccessControlUpgradeable, ReentrancyGuardUpgradeable, UUPSUpgradeable {
    // Custom Errors
    error EntityManager__EntityNotRegistered();
    error EntityManager__UnauthorizedUser();
    error EntityManager__OrganizationNotApproved();
    error EntityManager__EntityAlreadyExists();
    error EntityManager__ZeroAddressNotAllowed();

    // Structs
    using Structs for Structs.Metadata;

    struct Entity {
        uint256 id;
        address organization;
        bytes32 dataHash;
        string name;
        string description;
        string image;
        Structs.Attribute[] attributes;
    }

    // State Variables
    address private s_registry;
    mapping(uint256 => Entity) private s_entities;
    mapping(address => uint256[]) private s_entitiesByOrganization;
    mapping(bytes32 => uint256) private s_entityIdsByHash;
    uint256 private s_nextTokenId = 1;

    // Events
    event EntityRegistered(
        uint256 indexed entityId,
        address indexed orgAddress,
        bytes32 dataHash,
        string name,
        string description,
        string image
    );
    event EntityMetadataUpdated(uint256 indexed entityId, string name, string description, string image);

    /**
     * @notice Modifier to ensure a function is called only by the Contribution contract.
     */
    modifier onlyContributionContract() {
        if (msg.sender != _getContributionContractAddress()) {
            revert EntityManager__UnauthorizedUser();
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
            revert EntityManager__ZeroAddressNotAllowed();
        }
        __AccessControl_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        s_registry = registryAddress;
    }

    /**
     * @notice Allows an approved organization to register a new entity.
     * @param entityHash The hash of the entity data.
     * @param name The name of the entity.
     * @param description The description of the entity.
     * @param image The image of the entity.
     * @param attributes The attributes of the entity.
     */
    function registerEntity(
        bytes32 entityHash,
        string calldata name,
        string calldata description,
        string calldata image,
        Structs.Attribute[] calldata attributes
    ) external nonReentrant {
        address orgManagerAddress = _getOrgManagerAddress();
        // aderyn-fp-next-line(reentrancy-state-change)
        if (!OrganizationManager(payable(orgManagerAddress)).isApprovedOrganization(msg.sender)) {
            revert EntityManager__OrganizationNotApproved();
        }

        if (s_entityIdsByHash[entityHash] != 0) {
            revert EntityManager__EntityAlreadyExists();
        }

        uint256 entityId = s_nextTokenId++;
        s_entityIdsByHash[entityHash] = entityId;

        Entity storage newEntity = s_entities[entityId];
        newEntity.id = entityId;
        newEntity.organization = msg.sender;
        newEntity.dataHash = entityHash;
        newEntity.name = name;
        newEntity.description = description;
        newEntity.image = image;
        for (uint256 i = 0; i < attributes.length; i++) {
            newEntity.attributes.push(attributes[i]);
        }

        s_entitiesByOrganization[msg.sender].push(entityId);

        emit EntityRegistered(entityId, msg.sender, entityHash, name, description, image);
    }

    /**
     * @notice Updates the metadata of a registered entity.
     * @param entityId The ID of the entity.
     * @param name The name of the entity.
     * @param description The description of the entity.
     * @param image The image of the entity.
     * @param attributes The attributes of the entity.
     */
    function updateEntityMetadata(
        uint256 entityId,
        string calldata name,
        string calldata description,
        string calldata image,
        Structs.Attribute[] calldata attributes
    ) external nonReentrant {
        if (!isRegisteredEntity(entityId)) {
            revert EntityManager__EntityNotRegistered();
        }
        Entity storage entity = s_entities[entityId];
        if (entity.organization != msg.sender) {
            revert EntityManager__UnauthorizedUser();
        }

        entity.name = name;
        entity.description = description;
        entity.image = image;
        delete entity.attributes;
        for (uint256 i = 0; i < attributes.length; i++) {
            entity.attributes.push(attributes[i]);
        }

        address entityTokenAddress = _getEntityTokenAddress();
        try EntityToken(payable(entityTokenAddress)).getTokenIdByHash(entity.dataHash) returns (uint256 tokenId) {
            if (tokenId > 0) {
                EntityToken(payable(entityTokenAddress)).updateTokenURI(tokenId, name, description, image, attributes);
            }
        } catch Error(string memory) {
            // Ignora o erro se o token não for encontrado
        } catch (bytes memory) {
            // Ignora outros erros
        }

        emit EntityMetadataUpdated(entityId, name, description, image);
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

        Entity storage entity = s_entities[entityId];

        address entityTokenAddress = _getEntityTokenAddress();
        EntityToken(payable(entityTokenAddress)).safeMint(
            contributor, entity.dataHash, entity.name, entity.description, entity.image, entity.attributes
        );
    }

    /**
     * @notice Retrieves the hash of a registered entity.
     * @param entityId The ID of the entity.
     * @return The hash of the entity.
     */
    function getEntityHash(uint256 entityId) external view returns (bytes32) {
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
    function getEntityMetadata(uint256 entityId) external view returns (Structs.Metadata memory) {
        Entity storage entity = s_entities[entityId];
        Structs.Attribute[] memory attributes = new Structs.Attribute[](entity.attributes.length);
        for (uint256 i = 0; i < entity.attributes.length; i++) {
            attributes[i] = entity.attributes[i];
        }
        return Structs.Metadata(entity.name, entity.description, entity.image, attributes);
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
        return s_entities[entityId].id != 0;
    }

    /**
     * @dev Retrieves the OrganizationManager contract address from the registry.
     */
    function _getOrgManagerAddress() internal view returns (address) {
        return IRegistry(s_registry).getAddress(keccak256("ORGANIZATION_MANAGER"));
    }

    /**
     * @dev Retrieves the EntityToken contract address from the registry.
     */
    function _getEntityTokenAddress() internal view returns (address) {
        return IRegistry(s_registry).getAddress(keccak256("ENTITY_TOKEN"));
    }

    /**
     * @dev Retrieves the Contribution contract address from the registry.
     */
    function _getContributionContractAddress() internal view returns (address) {
        return IRegistry(s_registry).getAddress(keccak256("CONTRIBUTION"));
    }

    function _authorizeUpgrade(address newImplementation) internal view override onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newImplementation == address(0)) {
            revert EntityManager__ZeroAddressNotAllowed();
        }
    }
}

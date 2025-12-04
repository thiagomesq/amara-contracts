// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {ERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import {Structs} from "./libraries/Structs.sol";

/**
 * @title EntityToken
 * @author Thiago Mesquita
 * @notice This contract implements an ERC721 token to represent unique digital assets.
 * @dev Each token is linked to an off-chain data record via a keccak256 hash, allowing for
 *      verification and association. The contract is Ownable and managed by a designated
 *      EntityManager contract, which, along with the owner, has exclusive rights to mint new tokens.
 *      Metadata is stored on-chain using Base64 encoded JSON in the token URI.
 */
// aderyn-fp-next-line(contract-locks-ether)
contract EntityToken is ERC721Upgradeable, AccessControlUpgradeable, UUPSUpgradeable {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant UPDATER_ROLE = keccak256("UPDATER_ROLE");

    // Custom Errors
    error EntityToken__TokenIdNotFound();
    error EntityToken__ZeroAddressNotAllowed();
    error EntityToken__EntityAlreadyMinted();

    // State Variables
    uint256 private s_nextTokenId = 1;
    mapping(uint256 => bytes32) private s_assetToDataRecordHash;
    mapping(bytes32 => uint256) private hashToTokenId;
    mapping(uint256 => Structs.Metadata) private s_metadata;

    // Events
    event AssetLinkedToData(
        uint256 indexed tokenId, bytes32 indexed hashEntity, string name, string description, string image
    );
    event TokenURIUpdated(uint256 indexed tokenId, string name, string description, string image);

    // Modifiers
    modifier requireMinted(uint256 tokenId) {
        if (_ownerOf(tokenId) == address(0)) {
            revert EntityToken__TokenIdNotFound();
        }
        _;
    }

    /**
     * @dev Initializes the contract with the EntityManager address.
     * @param _entityManagerAddress Address of the deployed EntityManager contract.
     */
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    receive() external payable {
        revert();
    }

    function initialize(address admin) external initializer {
        if (admin == address(0)) {
            revert EntityToken__ZeroAddressNotAllowed();
        }

        __ERC721_init("Amara Entity Token", "AET");
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    /**
     * @notice Mints a new asset token.
     * @dev This function is designed to be called exclusively by the EntityManager contract or the owner.
     *      It creates the token and links it to the entity's hash.
     * @param to The address to mint the token to.
     * @param entityHash The hash of the entity data.
     * @param name The name for the token metadata.
     * @param description The description for the token metadata.
     * @param image The image URI for the token metadata.
     * @param attributes The attributes for the token metadata.
     */
    function safeMint(
        address to,
        bytes32 entityHash,
        string calldata name,
        string calldata description,
        string calldata image,
        Structs.Attribute[] calldata attributes
    ) external onlyRole(MINTER_ROLE) {
        if (hashToTokenId[entityHash] != 0) {
            revert EntityToken__EntityAlreadyMinted();
        }

        uint256 tokenId = s_nextTokenId++;
        s_assetToDataRecordHash[tokenId] = entityHash;
        hashToTokenId[entityHash] = tokenId;

        Structs.Metadata storage newMetadata = s_metadata[tokenId];
        newMetadata.name = name;
        newMetadata.description = description;
        newMetadata.image = image;
        for (uint256 i = 0; i < attributes.length; i++) {
            Structs.Attribute storage newAttribute = newMetadata.attributes.push();
            newAttribute.trait_type = attributes[i].trait_type;
            newAttribute.value = attributes[i].value;
        }

        _safeMint(to, tokenId);

        emit AssetLinkedToData(tokenId, entityHash, name, description, image);
    }

    /**
     * @notice Updates the token URI for a given token.
     * @param tokenId The ID of the token to update.
     * @param name The new name for the token metadata.
     * @param description The new description for the token metadata.
     * @param image The new image URI for the token metadata.
     * @param attributes The new attributes for the token metadata.
     */
    function updateTokenURI(
        uint256 tokenId,
        string calldata name,
        string calldata description,
        string calldata image,
        Structs.Attribute[] calldata attributes
    ) external onlyRole(UPDATER_ROLE) requireMinted(tokenId) {
        Structs.Metadata storage newMetadata = s_metadata[tokenId];
        newMetadata.name = name;
        newMetadata.description = description;
        newMetadata.image = image;

        delete newMetadata.attributes;
        for (uint256 i = 0; i < attributes.length; i++) {
            Structs.Attribute storage newAttribute = newMetadata.attributes.push();
            newAttribute.trait_type = attributes[i].trait_type;
            newAttribute.value = attributes[i].value;
        }

        emit TokenURIUpdated(tokenId, name, description, image);
    }

    /**
     * @notice Returns the token ID associated with a given hash.
     * @param hashEntity The hash of the entity data.
     * @return The token ID associated with the hash.
     */
    function getTokenIdByHash(bytes32 hashEntity) external view returns (uint256) {
        uint256 tokenId = hashToTokenId[hashEntity];
        if (tokenId == 0) {
            revert EntityToken__TokenIdNotFound();
        }
        return tokenId;
    }

    /**
     * @notice Returns the Uniform Resource Identifier (URI) for a token.
     * @dev This function is used to retrieve the metadata for a token.
     * @param tokenId The ID of the token to retrieve the URI for.
     * @return The URI for the token.
     */
    function tokenURI(uint256 tokenId) public view override requireMinted(tokenId) returns (string memory) {
        Structs.Metadata memory metadata = s_metadata[tokenId];

        string memory attributes = "";
        for (uint256 i = 0; i < metadata.attributes.length; i++) {
            attributes = string.concat(
                attributes,
                '{"trait_type":"',
                metadata.attributes[i].trait_type,
                '","value":"',
                metadata.attributes[i].value,
                '"}',
                i < metadata.attributes.length - 1 ? "," : ""
            );
        }

        string memory json = string.concat(
            '{"name":"',
            metadata.name,
            '",',
            '"description":"',
            metadata.description,
            '",',
            '"image":"',
            metadata.image,
            '",',
            '"attributes":[',
            attributes,
            "]",
            "}"
        );

        return string.concat("data:application/json;base64,", Base64.encode(bytes(json)));
    }

    /**
     * @notice See {ERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Upgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function _authorizeUpgrade(address newImplementation) internal view override onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newImplementation == address(0)) {
            revert EntityToken__ZeroAddressNotAllowed();
        }
    }
}

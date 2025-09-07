// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721URIStorage} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title EntityToken
 * @author Thiago Mesquita
 * @notice This contract implements an ERC721 token to represent unique digital assets.
 * @dev Each token is linked to an off-chain data record via a keccak256 hash, allowing for
 *      verification and association. The contract is Ownable and managed by a designated
 *      EntityManager contract, which, along with the owner, has exclusive rights to mint new tokens.
 *      Metadata is stored on-chain using Base64 encoded JSON in the token URI.
 */
contract EntityToken is ERC721URIStorage, Ownable {
    // Custom Errors
    error EntityToken__UnauthorizedUser();
    error EntityToken__TokenIdNotFound();

    // State Variables
    address private immutable i_entityManager;
    uint256 private s_nextTokenId = 1;

    mapping(uint256 => bytes32) private s_assetToDataRecordHash;
    mapping(bytes32 => uint256) private hashToTokenId;

    // Events
    event AssetLinkedToData(uint256 indexed tokenId, bytes32 indexed hashEntity);
    event ContributionContractSet(address indexed contributionContract);

    /**
     * @notice Modifier to ensure a function is called only by the EntityManager contract or the contract owner.
     */
    modifier onlyAuthorized() {
        if (msg.sender != i_entityManager && msg.sender != owner()) {
            revert EntityToken__UnauthorizedUser();
        }
        _;
    }

    /**
     * @dev Initializes the contract with the EntityManager address.
     * @param _entityManagerAddress Address of the deployed EntityManager contract.
     */
    constructor(address _entityManagerAddress)
        ERC721("Entity Asset", "EA")
        Ownable(msg.sender)
    {
        i_entityManager = _entityManagerAddress;
    }

    /**
     * @notice Mints a new asset token.
     * @dev This function is designed to be called exclusively by the EntityManager contract or the owner.
     *      It creates the token and links it to the entity's hash.
     * @param ownerAddress The address of the new token owner.
     * @param hashEntity The keccak256 hash of the entity document, used for linking.
     * @param tokenURI The Base64 encoded metadata for the token.
     */
    function safeMint(address ownerAddress, bytes32 hashEntity, string calldata tokenURI) external onlyAuthorized {
        uint256 tokenId = s_nextTokenId++;
        _safeMint(ownerAddress, tokenId);
        s_assetToDataRecordHash[tokenId] = hashEntity;
        hashToTokenId[hashEntity] = tokenId;
        _setTokenURI(tokenId, tokenURI);
        emit AssetLinkedToData(tokenId, hashEntity);
    }

    function updateTokenURI(uint256 tokenId, string calldata tokenURI) external onlyAuthorized {
        _setTokenURI(tokenId, tokenURI);
    }

    /**
     * @notice Retrieves the token ID associated with a given entity hash.
     * @dev Uses a reverse mapping for a gas-efficient O(1) lookup.
     * @param hashEntity The keccak256 hash of the entity to find the associated token ID.
     * @return The token ID associated with the given entity hash.
     */
    function getTokenIdByHash(bytes32 hashEntity) external view onlyAuthorized returns (uint256) {
        uint256 tokenId = hashToTokenId[hashEntity];
        if (tokenId == 0) {
            revert EntityToken__TokenIdNotFound();
        }
        return tokenId;
    }

    /**
     * @dev Returns the base URI for the token metadata.
     *      This is used to construct the full URI for each token.
     */
    function _baseURI() internal pure override returns (string memory) {
        return "data:application/json;base64,";
    }
}
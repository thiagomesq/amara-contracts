// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console} from "forge-std/Test.sol";
import {Contribution} from "../src/Contribution.sol";
import {OrganizationManager} from "../src/OrganizationManager.sol";
import {EntityManager} from "../src/EntityManager.sol";
import {EntityToken} from "../src/EntityToken.sol";
import {MockERC20Permit} from "./mocks/MockERC20Permit.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";

contract IntegrationTest is Test {
    Contribution private contribution;
    OrganizationManager private organizationManager;
    EntityManager private entityManager;
    EntityToken private entityToken;
    MockERC20Permit private token;

    address private constant OWNER = address(1);
    address private constant ORG_ACCOUNT = address(2);
    uint256 private constant USER_PRIVATE_KEY = 0x123;
    address private USER_ACCOUNT = vm.addr(USER_PRIVATE_KEY);

    string private constant ENTITY_METADATA = "{'name': 'Test Entity', 'description': 'A test entity for integration.'}";
    bytes32 private s_entityHash;

    function setUp() public {
        vm.startPrank(OWNER);
        organizationManager = new OrganizationManager();
        entityManager = new EntityManager(address(organizationManager));
        entityToken = new EntityToken(address(entityManager));
        contribution = new Contribution(address(organizationManager), address(entityManager));

        entityManager.setContributionContract(address(contribution));
        entityManager.setEntityToken(address(entityToken));
        vm.stopPrank();

        token = new MockERC20Permit("Mock Token", "MTK", USER_ACCOUNT, 1_000_000 ether);

        s_entityHash = keccak256(abi.encodePacked("some data"));
    }

    function _getPermitSignature(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint256 privateKey
    ) internal view returns (uint8 v, bytes32 r, bytes32 s) {
        bytes32 digest = token.getPermitDigest(owner, spender, value, deadline);
        (v, r, s) = vm.sign(privateKey, digest);
    }

    function test_FullFlow_RegisterOrg_RegisterEntity_Subscribe_MintToken() public {
        // 1. Register and approve organization
        vm.prank(ORG_ACCOUNT);
        organizationManager.registerOrganization("Test Org");
        vm.prank(OWNER);
        organizationManager.setActive(ORG_ACCOUNT);

        // 2. Organization registers an entity
        vm.prank(ORG_ACCOUNT);
        entityManager.registerEntity(Base64.encode(bytes(ENTITY_METADATA)), s_entityHash);

        // 3. User subscribes to the entity using ERC20 with permit
        uint256 amount = 100 ether;
        uint256 interval = 30 days;
        uint256 deadline = block.timestamp + 1 hours;

        (uint8 v, bytes32 r, bytes32 s) = _getPermitSignature(USER_ACCOUNT, address(contribution), amount, deadline, USER_PRIVATE_KEY);

        vm.prank(USER_ACCOUNT);
        contribution.subscribe(ORG_ACCOUNT, 1, address(token), amount, interval, deadline, v, r, s);

        // 4. Assertions
        uint256 serviceFee = (amount * contribution.getServiceFee()) / 100;
        uint256 expectedOrgAmount = amount - serviceFee;

        // Assert token balances
        assertEq(token.balanceOf(ORG_ACCOUNT), expectedOrgAmount);
        assertEq(token.balanceOf(OWNER), serviceFee);
        assertEq(token.balanceOf(USER_ACCOUNT), (1_000_000 ether) - amount);

        // Assert EntityToken was minted to the user
        assertEq(entityToken.ownerOf(1), USER_ACCOUNT);

        // Assert token URI is correct
        string memory tokenURI = entityToken.tokenURI(1);
        string memory expectedURI =
            string(abi.encodePacked("data:application/json;base64,", Base64.encode(bytes(ENTITY_METADATA))));
        assertEq(tokenURI, expectedURI);
    }
}

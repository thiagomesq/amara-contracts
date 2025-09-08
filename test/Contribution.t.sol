// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console} from "forge-std/Test.sol";
import {Contribution} from "../src/Contribution.sol";
import {OrganizationManager} from "../src/OrganizationManager.sol";
import {EntityManager} from "../src/EntityManager.sol";
import {EntityToken} from "../src/EntityToken.sol";
import {MockERC20Permit} from "./mocks/MockERC20Permit.sol";

contract ContributionTest is Test {
    Contribution private contribution;
    OrganizationManager private organizationManager;
    EntityManager private entityManager;
    EntityToken private entityToken;
    MockERC20Permit private token;

    address private constant OWNER = address(1);
    address private constant ORG_ACCOUNT = address(2);
    uint256 private constant USER_PRIVATE_KEY = 0x123;
    address private USER_ACCOUNT = vm.addr(USER_PRIVATE_KEY);

    uint256 private constant CONTRIBUTION_AMOUNT = 100 ether;
    uint256 private constant INITIAL_SUPPLY = 1_000_000 ether;

    function setUp() public {
        vm.startPrank(OWNER);
        organizationManager = new OrganizationManager();
        entityManager = new EntityManager(address(organizationManager));
        entityToken = new EntityToken(address(entityManager));
        contribution = new Contribution(address(organizationManager), address(entityManager));

        entityManager.setContributionContract(address(contribution));
        entityManager.setEntityToken(address(entityToken));
        vm.stopPrank();

        vm.startPrank(ORG_ACCOUNT);
        organizationManager.registerOrganization("Org Name");
        vm.stopPrank();

        vm.startPrank(OWNER);
        organizationManager.setActive(ORG_ACCOUNT);
        vm.stopPrank();

        vm.prank(ORG_ACCOUNT);
        entityManager.registerEntity("metadata", keccak256("entity"));

        token = new MockERC20Permit("Mock Token", "MTK", USER_ACCOUNT, INITIAL_SUPPLY);
    }

    // Helper function to get permit signature
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

    function test_DepositAndContribute() public {
        // Arrange
        uint256 deadline = block.timestamp + 1 hours;
        (uint8 v, bytes32 r, bytes32 s) = _getPermitSignature(
            USER_ACCOUNT, address(contribution), CONTRIBUTION_AMOUNT, deadline, USER_PRIVATE_KEY
        );

        // Act
        vm.prank(USER_ACCOUNT);
        contribution.depositAndContribute(ORG_ACCOUNT, address(token), CONTRIBUTION_AMOUNT, deadline, v, r, s);

        // Assert
        assertEq(token.balanceOf(ORG_ACCOUNT), CONTRIBUTION_AMOUNT);
        assertEq(token.balanceOf(USER_ACCOUNT), INITIAL_SUPPLY - CONTRIBUTION_AMOUNT);
    }

    function test_Subscribe() public {
        // Arrange
        uint256 deadline = block.timestamp + 1 hours;
        uint256 interval = 30 days;
        (uint8 v, bytes32 r, bytes32 s) = _getPermitSignature(
            USER_ACCOUNT, address(contribution), CONTRIBUTION_AMOUNT, deadline, USER_PRIVATE_KEY
        );

        // Act
        vm.prank(USER_ACCOUNT);
        contribution.subscribe(ORG_ACCOUNT, 1, address(token), CONTRIBUTION_AMOUNT, interval, deadline, v, r, s);

        // Assert
        assertEq(token.balanceOf(ORG_ACCOUNT), CONTRIBUTION_AMOUNT);
        assertEq(token.balanceOf(USER_ACCOUNT), INITIAL_SUPPLY - CONTRIBUTION_AMOUNT);
        // Check subscription details if needed
    }

    function test_RenewSubscription() public {
        // Arrange: Initial subscription
        uint256 deadline = block.timestamp + 1 hours;
        uint256 interval = 30 days;
        (uint8 v, bytes32 r, bytes32 s) = _getPermitSignature(
            USER_ACCOUNT, address(contribution), CONTRIBUTION_AMOUNT, deadline, USER_PRIVATE_KEY
        );
        vm.prank(USER_ACCOUNT);
        contribution.subscribe(ORG_ACCOUNT, 1, address(token), CONTRIBUTION_AMOUNT, interval, deadline, v, r, s);

        // Arrange: Move time forward and get new signature
        vm.warp(block.timestamp + interval + 1);
        uint256 renewalDeadline = block.timestamp + 1 hours;
        (uint8 v2, bytes32 r2, bytes32 s2) = _getPermitSignature(
            USER_ACCOUNT, address(contribution), CONTRIBUTION_AMOUNT, renewalDeadline, USER_PRIVATE_KEY
        );

        // Act
        vm.prank(USER_ACCOUNT);
        contribution.renewSubscription(1, renewalDeadline, v2, r2, s2);

        // Assert
        assertEq(token.balanceOf(ORG_ACCOUNT), CONTRIBUTION_AMOUNT * 2);
        assertEq(token.balanceOf(USER_ACCOUNT), INITIAL_SUPPLY - (CONTRIBUTION_AMOUNT * 2));
    }

    function test_ServiceFee() public {
        // Arrange
        uint8 serviceFee = 10; // 10%
        vm.prank(OWNER);
        contribution.setServiceFee(serviceFee);

        uint256 deadline = block.timestamp + 1 hours;
        (uint8 v, bytes32 r, bytes32 s) = _getPermitSignature(
            USER_ACCOUNT, address(contribution), CONTRIBUTION_AMOUNT, deadline, USER_PRIVATE_KEY
        );

        // Act
        vm.prank(USER_ACCOUNT);
        contribution.depositAndContribute(ORG_ACCOUNT, address(token), CONTRIBUTION_AMOUNT, deadline, v, r, s);

        // Assert
        uint256 expectedFee = (CONTRIBUTION_AMOUNT * serviceFee) / 100;
        uint256 expectedOrgAmount = CONTRIBUTION_AMOUNT - expectedFee;

        assertEq(token.balanceOf(ORG_ACCOUNT), expectedOrgAmount);
        assertEq(token.balanceOf(address(contribution)), 0);
        assertEq(token.balanceOf(OWNER), expectedFee);
        assertEq(token.balanceOf(USER_ACCOUNT), INITIAL_SUPPLY - CONTRIBUTION_AMOUNT);
    }

    function test_RevertIf_SetInvalidServiceFee() public {
        vm.prank(OWNER);
        vm.expectRevert(Contribution.Contribution__InvalidServiceFee.selector);
        contribution.setServiceFee(101);
    }
}

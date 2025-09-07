// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {TestBase} from "./TestBase.sol";
import {OrganizationManager} from "../src/OrganizationManager.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract OrganizationManagerTest is TestBase {
    string private constant ORG_NAME = "Test Org";

    function setUp() public override {
        super.setUp();
    }

    function test_RegisterOrganization() public {
        vm.prank(ORG_ACCOUNT);
        organizationManager.registerOrganization(ORG_NAME);

        (string memory name, OrganizationManager.OrganizationStatus status) = organizationManager.organizations(ORG_ACCOUNT);
        assertEq(name, ORG_NAME);
        assertEq(uint(status), uint(OrganizationManager.OrganizationStatus.PENDING));
    }

    function test_RevertIf_OrganizationAlreadyExists() public {
        vm.prank(ORG_ACCOUNT);
        organizationManager.registerOrganization(ORG_NAME);

        vm.prank(ORG_ACCOUNT);
        vm.expectRevert(OrganizationManager.OrganizationManager__OrganizationAlreadyExists.selector);
        organizationManager.registerOrganization(ORG_NAME);
    }

    function test_SetOrganizationStatus() public {
        vm.prank(ORG_ACCOUNT);
        organizationManager.registerOrganization(ORG_NAME);

        vm.prank(OWNER);
        organizationManager.setOrganizationStatus(ORG_ACCOUNT, OrganizationManager.OrganizationStatus.APPROVED);

        (, OrganizationManager.OrganizationStatus status) = organizationManager.organizations(ORG_ACCOUNT);
        assertEq(uint(status), uint(OrganizationManager.OrganizationStatus.APPROVED));
    }

    function test_RevertIf_NonOwnerSetsStatus() public {
        vm.prank(ORG_ACCOUNT);
        organizationManager.registerOrganization(ORG_NAME);

        vm.prank(ORG_ACCOUNT); // Not the owner
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, ORG_ACCOUNT));
        organizationManager.setOrganizationStatus(ORG_ACCOUNT, OrganizationManager.OrganizationStatus.APPROVED);
    }

    function test_IsApprovedOrganization() public {
        vm.prank(ORG_ACCOUNT);
        organizationManager.registerOrganization(ORG_NAME);

        vm.prank(OWNER);
        organizationManager.setOrganizationStatus(ORG_ACCOUNT, OrganizationManager.OrganizationStatus.APPROVED);

        assertTrue(organizationManager.isApprovedOrganization(ORG_ACCOUNT));
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {Deploy} from "../script/Deploy.s.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";
import {OrganizationManager} from "../src/OrganizationManager.sol";
import {EntityManager} from "../src/EntityManager.sol";
import {EntityToken} from "../src/EntityToken.sol";
import {Contribution} from "../src/Contribution.sol";

contract TestBase is Test {
    Deploy internal deployer;
    OrganizationManager internal organizationManager;
    EntityManager internal entityManager;
    EntityToken internal entityToken;
    Contribution internal contribution;

    address internal OWNER;
    address internal ORG_ACCOUNT;
    address internal CONTRIBUTOR_ACCOUNT;

    function setUp() public virtual {
        deployer = new Deploy();
        (organizationManager, entityManager, entityToken, contribution) = deployer.run();

        HelperConfig helperConfig = new HelperConfig();
        OWNER = helperConfig.getConfig().account;
        ORG_ACCOUNT = makeAddr("org");
        CONTRIBUTOR_ACCOUNT = makeAddr("contributor");
    }
}

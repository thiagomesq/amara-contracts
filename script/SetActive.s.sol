// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {OrganizationManager} from "../src/OrganizationManager.sol";
import {EntityManager} from "../src/EntityManager.sol";
import {EntityToken} from "../src/EntityToken.sol";
import {Contribution} from "../src/Contribution.sol";
import {DevOpsTools} from "../lib/foundry-devops/src/DevOpsTools.sol";

contract SetActive is Script {
    
    HelperConfig internal helperConfig;
    OrganizationManager internal organizationManager;
    EntityManager internal entityManager;
    EntityToken internal entityToken;
    Contribution internal contribution;

    function run() public {
        helperConfig = new HelperConfig();
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("OrganizationManager", block.chainid);
        organizationManager = OrganizationManager(mostRecentlyDeployed);
        vm.startBroadcast(helperConfig.getConfig().account);
        address orgAddress = 0xe7FDf6cA472c484FA8b7b2E11a5E62adaF1e649F;
        organizationManager.setOrganizationStatus(orgAddress, OrganizationManager.OrganizationStatus.APPROVED);
        vm.stopBroadcast();
    }
}

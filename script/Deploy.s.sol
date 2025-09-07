// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {OrganizationManager} from "../src/OrganizationManager.sol";
import {EntityManager} from "../src/EntityManager.sol";
import {EntityToken} from "../src/EntityToken.sol";
import {Contribution} from "../src/Contribution.sol";

/**
 * @title Deploy
 * @author Thiago Mesquita
 * @notice Deploys all contracts in the correct order.
 */
contract Deploy is Script {
    function run() external returns (OrganizationManager, EntityManager, EntityToken, Contribution) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        vm.startBroadcast(config.account);

        // 1. Deploy OrganizationManager
        OrganizationManager organizationManager = new OrganizationManager();

        // 2. Deploy EntityManager
        EntityManager entityManager = new EntityManager(address(organizationManager));

        // 3. Deploy EntityToken
        EntityToken entityToken = new EntityToken(address(entityManager));

        // 4. Deploy Contribution
        Contribution contribution = new Contribution(address(organizationManager), address(entityManager));

        // 5. Set contract addresses
        entityManager.setEntityToken(address(entityToken));
        entityManager.setContributionContract(address(contribution));

        vm.stopBroadcast();

        return (organizationManager, entityManager, entityToken, contribution);
    }
}

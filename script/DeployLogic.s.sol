// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {Registry} from "../src/Registry.sol";
import {OrganizationManager} from "../src/OrganizationManager.sol";
import {EntityManager} from "../src/EntityManager.sol";
import {EntityToken} from "../src/EntityToken.sol";
import {Contribution} from "../src/Contribution.sol";

/**
 * @title DeployLogic
 * @author Cascade
 * @notice Deploys the entire UUPS-based architecture.
 */
contract DeployLogic is Script {
    bytes32 public constant ORGANIZATION_MANAGER_ID = keccak256("ORGANIZATION_MANAGER");
    bytes32 public constant ENTITY_MANAGER_ID = keccak256("ENTITY_MANAGER");
    bytes32 public constant ENTITY_TOKEN_ID = keccak256("ENTITY_TOKEN");
    bytes32 public constant CONTRIBUTION_ID = keccak256("CONTRIBUTION");

    function run() external {
        HelperConfig.NetworkConfig memory config = new HelperConfig().getConfig();

        vm.startBroadcast(config.account);

        // 1. Deploy Registry
        new Registry(config.admin);

        // 2. Deploy Logic Contracts
        new OrganizationManager();
        new EntityManager();
        new EntityToken();
        new Contribution();

        vm.stopBroadcast();
    }
}

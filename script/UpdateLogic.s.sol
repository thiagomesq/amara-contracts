// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {HelperConfig} from "./HelperConfig.s.sol";
import {Script} from "forge-std/Script.sol";
import {Registry} from "src/Registry.sol";
import {DevOpsTools} from "foundry-devops/src/DevOpsTools.sol";
import {OrganizationManager} from "src/OrganizationManager.sol";
import {EntityManager} from "src/EntityManager.sol";
import {EntityToken} from "src/EntityToken.sol";
import {Contribution} from "src/Contribution.sol";

contract UpdateLogic is Script {
    bytes32 public constant ORGANIZATION_MANAGER_ID = keccak256("ORGANIZATION_MANAGER");
    bytes32 public constant ENTITY_MANAGER_ID = keccak256("ENTITY_MANAGER");
    bytes32 public constant ENTITY_TOKEN_ID = keccak256("ENTITY_TOKEN");
    bytes32 public constant CONTRIBUTION_ID = keccak256("CONTRIBUTION");

    function run() public {
        HelperConfig.NetworkConfig memory config = new HelperConfig().getConfig();

        vm.startBroadcast(config.admin);

        Registry registry = Registry(DevOpsTools.get_most_recent_deployment("Registry", block.chainid));

        OrganizationManager(payable(registry.getAddress(ORGANIZATION_MANAGER_ID))).upgradeTo(
            address(new OrganizationManager())
        );
        EntityManager(payable(registry.getAddress(ENTITY_MANAGER_ID))).upgradeTo(address(new EntityManager()));
        EntityToken(payable(registry.getAddress(ENTITY_TOKEN_ID))).upgradeTo(address(new EntityToken()));
        Contribution(payable(registry.getAddress(CONTRIBUTION_ID))).upgradeTo(address(new Contribution()));

        vm.stopBroadcast();
    }
}

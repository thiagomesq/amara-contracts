// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {Registry} from "../src/Registry.sol";
import {EntityToken} from "../src/EntityToken.sol";
import {DevOpsTools} from "foundry-devops/src/DevOpsTools.sol";

contract GrantRoles is Script {
    bytes32 public constant ENTITY_TOKEN_ID = keccak256("ENTITY_TOKEN");
    bytes32 public constant ENTITY_MANAGER_ID = keccak256("ENTITY_MANAGER");

    function run() public {
        HelperConfig.NetworkConfig memory config = new HelperConfig().getConfig();

        vm.startBroadcast(config.admin);

        Registry registry = Registry(DevOpsTools.get_most_recent_deployment("Registry", block.chainid, config.broadcastPath));

        address entityManagerAddress = registry.getAddress(ENTITY_MANAGER_ID);
        address entityTokenAddress = registry.getAddress(ENTITY_TOKEN_ID);

        bytes32 minterRole = EntityToken(payable(entityTokenAddress)).MINTER_ROLE();
        EntityToken(payable(entityTokenAddress)).grantRole(minterRole, entityManagerAddress);

        bytes32 updaterRole = EntityToken(payable(entityTokenAddress)).UPDATER_ROLE();
        EntityToken(payable(entityTokenAddress)).grantRole(updaterRole, entityManagerAddress);

        vm.stopBroadcast();
    }
}

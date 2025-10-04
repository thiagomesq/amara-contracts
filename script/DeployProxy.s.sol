// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {DevOpsTools} from "foundry-devops/src/DevOpsTools.sol";
import {Registry} from "../src/Registry.sol";
import {OrganizationManager} from "../src/OrganizationManager.sol";
import {EntityManager} from "../src/EntityManager.sol";
import {EntityToken} from "../src/EntityToken.sol";
import {Contribution} from "../src/Contribution.sol";

/**
 * @title DeployProxy
 * @author Cascade
 * @notice Deploys the proxies for the UUPS-based architecture.
 */
contract DeployProxy is Script {
    bytes32 public constant ORGANIZATION_MANAGER_ID = keccak256("ORGANIZATION_MANAGER");
    bytes32 public constant ENTITY_MANAGER_ID = keccak256("ENTITY_MANAGER");
    bytes32 public constant ENTITY_TOKEN_ID = keccak256("ENTITY_TOKEN");
    bytes32 public constant CONTRIBUTION_ID = keccak256("CONTRIBUTION");

    function run()
        public
        returns (
            address orgManagerProxyAddress,
            address entityManagerProxyAddress,
            address entityTokenProxyAddress,
            address contributionProxyAddress
        )
    {
        HelperConfig.NetworkConfig memory config = new HelperConfig().getConfig();

        vm.startBroadcast(config.account);

        // 3. Deploy Proxies
        orgManagerProxyAddress =
            address(new ERC1967Proxy(DevOpsTools.get_most_recent_deployment("OrganizationManager", block.chainid), ""));
        entityManagerProxyAddress =
            address(new ERC1967Proxy(DevOpsTools.get_most_recent_deployment("EntityManager", block.chainid), ""));
        entityTokenProxyAddress =
            address(new ERC1967Proxy(DevOpsTools.get_most_recent_deployment("EntityToken", block.chainid), ""));
        contributionProxyAddress =
            address(new ERC1967Proxy(DevOpsTools.get_most_recent_deployment("Contribution", block.chainid), ""));

        Registry registry = Registry(DevOpsTools.get_most_recent_deployment("Registry", block.chainid));

        OrganizationManager(payable(orgManagerProxyAddress)).initialize(config.admin);
        EntityManager(payable(entityManagerProxyAddress)).initialize(address(registry), config.admin);
        EntityToken(payable(entityTokenProxyAddress)).initialize(config.admin);
        Contribution(payable(contributionProxyAddress)).initialize(address(registry), config.admin);

        vm.stopBroadcast();

        vm.startBroadcast(config.admin);

        registry.setAddress(ORGANIZATION_MANAGER_ID, orgManagerProxyAddress);
        registry.setAddress(ENTITY_MANAGER_ID, entityManagerProxyAddress);
        registry.setAddress(ENTITY_TOKEN_ID, entityTokenProxyAddress);
        registry.setAddress(CONTRIBUTION_ID, contributionProxyAddress);

        vm.stopBroadcast();
    }
}

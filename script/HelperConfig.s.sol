// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";

contract HelperConfig is Script {
    error HelperConfig__InvalidChainId();

    struct NetworkConfig {
        address account;
    }

    uint256 constant LOCAL_CHAIN_ID = 31337;
    uint256 constant ETH_AMOY_CHAIN_ID = 80002;
    uint256 constant POLYGON_MAINNET_CHAIN_ID = 137;

    NetworkConfig public localNetworkConfig;
    mapping(uint256 => NetworkConfig) public networkConfigs;

    constructor() {
        networkConfigs[ETH_AMOY_CHAIN_ID] = getAmoyConfig();
        networkConfigs[POLYGON_MAINNET_CHAIN_ID] = getPolygonConfig();
    }

    function getConfigChainId(uint256 chainId) public view returns (NetworkConfig memory) {
        if (chainId == LOCAL_CHAIN_ID) {
            return getOrCreateAnvilEthConfig();
        } else {
            return networkConfigs[chainId];
        }
    }

    function getConfig() public view returns (NetworkConfig memory) {
        return getConfigChainId(block.chainid);
    }

    function getAmoyConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({account: 0xe7FDf6cA472c484FA8b7b2E11a5E62adaF1e649F});
    }

    function getPolygonConfig() public pure returns (NetworkConfig memory) {
        // price feed address
        return NetworkConfig({account: 0xe7FDf6cA472c484FA8b7b2E11a5E62adaF1e649F});
    }

    function getOrCreateAnvilEthConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({account: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266});
    }
}

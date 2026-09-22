// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";

contract HelperConfig is Script {
    error HelperConfig__InvalidChainId();

    struct NetworkConfig {
        address account;
        address admin;
        string broadcastPath;
    }

    uint256 constant LOCAL_CHAIN_ID = 31337;
    uint256 constant LINEA_SEPOLIA_CHAIN_ID = 59141;
    uint256 constant LINEA_MAINNET_CHAIN_ID = 59144;

    NetworkConfig public localNetworkConfig;
    mapping(uint256 => NetworkConfig) public networkConfigs;

    constructor() {
        networkConfigs[LINEA_SEPOLIA_CHAIN_ID] = getLineaSepoliaConfig();
        networkConfigs[LINEA_MAINNET_CHAIN_ID] = getLineaMainnetConfig();
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

    function getLineaSepoliaConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            account: 0x680488a9b679C04C48966c9E42E44769F4aaa2fc,
            admin: 0x680488a9b679C04C48966c9E42E44769F4aaa2fc,
            broadcastPath: "./broadcast/DeployLogic.s.sol/59141/run-latest.json"
        });
    }

    function getLineaMainnetConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            account: 0x680488a9b679C04C48966c9E42E44769F4aaa2fc,
            admin: 0x680488a9b679C04C48966c9E42E44769F4aaa2fc,
            broadcastPath: "./broadcast/DeployLogic.s.sol/59144/run-latest.json"
        });
    }

    function getOrCreateAnvilEthConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            account: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266,
            admin: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266,
            broadcastPath: "./broadcast/DeployLogic.s.sol/31337/run-latest.json"
        });
    }
}

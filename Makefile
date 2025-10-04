-include .env

.PHONY: all test clean deploy fund help install snapshot format anvil 

DEFAULT_ANVIL_KEY := 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

help:
	@echo "Usage:"
	@echo "  make deploy [ARGS=...]\n    example: make deploy ARGS=\"--network sepolia\""
	@echo ""
	@echo "  make fund [ARGS=...]\n    example: make deploy ARGS=\"--network sepolia\""

all: clean remove install update build

# Clean the repo
clean  :; forge clean

# Remove modules
remove :; rm -rf .gitmodules && rm -rf .git/modules/* && rm -rf lib && touch .gitmodules && git add . && git commit -m "modules"

install :; forge install cyfrin/foundry-devops && forge install foundry-rs/forge-std && forge install OpenZeppelin/openzeppelin-contracts@v4.9.6 && forge install OpenZeppelin/openzeppelin-contracts-upgradeable@v4.9.6

# Update Dependencies
update:; forge update

build:; forge build --via-ir

test :; forge test

coverage :; forge coverage --via-ir --ir-minimum

snapshot :; forge snapshot

format :; forge fmt

anvil :; anvil -m 'test test test test test test test test test test test junk' --steps-tracing --block-time 1

NETWORK_ARGS := --rpc-url http://localhost:8545 --private-key $(DEFAULT_ANVIL_KEY) --broadcast -vvvvv

ifeq ($(findstring --network sepolia,$(ARGS)),--network sepolia)
	NETWORK_ARGS := --rpc-url sepolia --account $(ACCOUNT) --broadcast --verify --verifier etherscan --etherscan-api-key $(ETHERSCAN_API_KEY)
else ifeq ($(findstring --network mainnet,$(ARGS)),--network mainnet)
	NETWORK_ARGS := --rpc-url mainnet --account $(ACCOUNT) --broadcast --verify --verifier etherscan --etherscan-api-key $(ETHERSCAN_API_KEY)
endif 

deploy-logic: ## Deploy the logic contracts
	@forge script script/DeployLogic.s.sol:DeployLogic $(NETWORK_ARGS)

deploy-proxy: ## Deploy the proxies
	@forge script script/DeployProxy.s.sol:DeployProxy $(NETWORK_ARGS) --slow

grant-roles: ## Grant roles
	@forge script script/GrantRoles.s.sol:GrantRoles $(NETWORK_ARGS)

update-logic: ## Update logic contracts
	@forge script script/UpdateLogic.s.sol:UpdateLogic $(NETWORK_ARGS) --slow
	
	
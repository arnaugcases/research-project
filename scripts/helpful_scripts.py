from brownie import network, config, accounts
from web3 import Web3

# To distinguish between ethereum chains and our local ganache chain (dev)
LOCAL_BLOCKCHAIN_ENVIRONMENTS = ["development", "ganache-rp"]


def get_account(index):
    if network.show_active() in LOCAL_BLOCKCHAIN_ENVIRONMENTS:
        return accounts[index]
    else:
        return accounts.add(config["wallets"]["from_key"])
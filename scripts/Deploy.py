from brownie import SatDetails, network, config
from scripts.helpful_scripts import get_account, LOCAL_BLOCKCHAIN_ENVIRONMENTS


def deploy_satDetails():
    account = get_account(0)

    satDetails = SatDetails.deploy(
        {"from": account},
        publish_source=config["networks"][network.show_active()].get("verify"),
    )
    print(f"Contract deployed to {satDetails.address}")
    return satDetails


def main():
    deploy_satDetails()

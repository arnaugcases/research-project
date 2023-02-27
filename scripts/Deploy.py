from brownie import AircraftDatabase, network, config
from scripts.helpful_scripts import get_account, LOCAL_BLOCKCHAIN_ENVIRONMENTS


def deploy_aircraft_dabase():
    account = get_account(0)

    aircraft_details = AircraftDatabase.deploy(
        {"from": account},
        publish_source=config["networks"][network.show_active()].get("verify"),
    )
    print(f"Contract deployed to {aircraft_details.address}")
    return aircraft_details


def main():
    deploy_aircraft_dabase()
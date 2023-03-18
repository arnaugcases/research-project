from brownie import AircraftDatabase, StateEstimation, Reputation, Trigonometry, network, config
from scripts.helpful_scripts import get_account, LOCAL_BLOCKCHAIN_ENVIRONMENTS


def deploy_aircraft_database():
    account = get_account(0)
    # Deploy libraries
    trigonometry = Trigonometry.deploy({"from": account})
    state_estimation = StateEstimation.deploy({"from": account})
    reputation = Reputation.deploy({"from": account})

    # Deploy main smart contract
    aircraft_details = AircraftDatabase.deploy(
        {"from": account},
        publish_source=config["networks"][network.show_active()].get("verify"),
    )

    print(f"AircraftDatabase contract deployed to {aircraft_details.address}")
    return aircraft_details


def main():
    # Deploy the smart contract
    deploy_aircraft_database()
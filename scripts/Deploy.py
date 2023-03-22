from brownie import AircraftDatabase, StateEstimation, Reputation, Trigonometry, network, config
from scripts.helpful_scripts import get_account, LOCAL_BLOCKCHAIN_ENVIRONMENTS


def deploy_aircraft_database():
    account = get_account(0)
    # Deploy libraries
    trigonometry = Trigonometry.deploy({"from": account})
    print(f"Trigonometry library deployed to {trigonometry.address}\n")
    state_estimation = StateEstimation.deploy({"from": account})
    print(f"StateEstimation library deployed to {state_estimation.address}\n")
    reputation = Reputation.deploy({"from": account})
    print(f"Reputation Library deployed to {reputation.address}\n")

    # Deploy main smart contract
    aircraft_details = AircraftDatabase.deploy(
        {"from": account},
        publish_source=config["networks"][network.show_active()].get("verify"),
    )

    print(f"AircraftDatabase contract deployed to {aircraft_details.address}\n")
    return aircraft_details


def main():
    # Deploy the smart contract
    deploy_aircraft_database()
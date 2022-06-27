from brownie import SatDetails, accounts, network, config, exceptions
from scripts.Deploy import deploy_satDetails
from scripts.helpful_scripts import get_account
import numpy as np

satInfo = [
    {"id": 1, "apogee": 534000, "perigee": 513000, "inclination": 9751},
    {"id": 2, "apogee": 500000, "perigee": 480000, "inclination": 4500},
    {"id": 3, "apogee": 800000, "perigee": 795000, "inclination": 1545},
    {"id": 4, "apogee": 3650000, "perigee": 3600000, "inclination": 500},
]

totalSatellites = 1
totalAccounts = 5

submittedData = [
    {"id": 1, "apogee": [], "perigee": [], "inclination": []},
    {"id": 2, "apogee": [], "perigee": [], "inclination": []},
    {"id": 3, "apogee": [], "perigee": [], "inclination": []},
    {"id": 4, "apogee": [], "perigee": [], "inclination": []},
]


def submitData():
    account = get_account(0)

    if network.show_active() == "development":
        print("Deploy contract!")
        satDetails = SatDetails.deploy(
            {"from": account},
            publish_source=config["networks"][network.show_active()].get("verify"),
        )
    else:
        satDetails = SatDetails[-1]

    for accountIndex in range(0, totalAccounts):
        account = get_account(accountIndex)

        for satIndex in range(0, totalSatellites):
            noise = np.random.normal(0, 1)
            id = satInfo[satIndex]["id"]
            inclination = satInfo[satIndex]["inclination"] + int(
                noise * 15 * (satIndex + 1)
            )
            apogee = satInfo[satIndex]["apogee"] + int(noise * 150 * (satIndex + 1))
            perigee = satInfo[satIndex]["perigee"] + int(noise * 150 * (satIndex + 1))

            submittedData[satIndex]["apogee"].append(apogee)
            submittedData[satIndex]["inclination"].append(inclination)
            submittedData[satIndex]["perigee"].append(perigee)

            print(f"Submit data for satellite {id} and account {accountIndex}")
            transaction = satDetails.submitSatDetails(
                id, inclination, apogee, perigee, {"from": account}
            )

            try:
                satIdTx = transaction.events["trustScoreComputed"]["satId"]
                iterationsTx = transaction.events["trustScoreComputed"]["iteration"]

                print(f"Transaction submitted for satellite {satIdTx}")
                print(f"Iterations done to compute trust: {iterationsTx}")
                break
            except exceptions.EventLookupError:
                pass

    transaction.wait(1)

    return satDetails


def readParameters(satDetails):
    for satIndex in range(0, totalSatellites):
        id = satInfo[satIndex]["id"]
        (id, inclination, apogee, perigee) = satDetails.viewSatDetails(id)

        inclinationReal = satInfo[satIndex]["inclination"]
        apogeeReal = satInfo[satIndex]["apogee"]
        perigeeReal = satInfo[satIndex]["perigee"]

        (
            inclinationOcc,
            apogeeOcc,
            perigeeOcc,
            observers,
        ) = satDetails.viewSatOccurences(id)

        print("--------------------------------------------------------")
        print(f"Satellite {id} (inclination, apogee, perigee): ")
        print(f"Real values: {inclinationReal}, {apogeeReal}, {perigeeReal}")
        print(f"Consensus values: {inclination}, {apogee}, {perigee}")
        print("")
        print(f"Inclination occurences: {inclinationOcc}")
        print(f"Apogee occurences: {apogeeOcc}")
        print(f"Perigee occurences: {perigeeOcc}")
        print(f"Observers: {observers}")
        print("--------------------------------------------------------")

    # print("The final trust scores and reputation are:\n")
    # for accountIndex in range(0, totalAccounts):
    #     account = get_account(accountIndex)
    #     (scores, reputation) = satDetails.viewReputation()
    #     print(f"Address: {account}")
    #     print(f"Trust scores: {scores}")
    #     print(f"Reputation: {reputation}\n")


def display_data():
    print("The data used for this run is the following:")

    for satIndex in range(0, totalSatellites):
        id = submittedData[satIndex]["id"]
        inclination = submittedData[satIndex]["inclination"]
        perigee = submittedData[satIndex]["perigee"]
        apogee = submittedData[satIndex]["apogee"]

        print(f"Satellite {id}")
        print(f"Inclination: {inclination}")
        print(f"Apogee: {apogee}")
        print(f"Perigee: {perigee}")
        print("")


def main():
    satDetails = submitData()
    readParameters(satDetails)
    # display_data()

from brownie import AircraftDatabase, accounts, network, config, exceptions
from scripts.Deploy import deploy_aircraft_database
from scripts.helpful_scripts import get_account
import json
import numpy as np
import time

TOTAL_ACCOUNTS = 5      # Max 10
TOTAL_EPOCHS = 5       # Max 50
TOTAL_AIRCRAFT = 5      # Max 10

# Algorithm variables
TOTAL_MALICIOUS_ACCOUNTS = 2
ERRONEOUS_AIRCRAFT = 2
REPUTATION_ALGORITHM = 0    # 0 - simple average; 1 - weighted average 

TRUST_RESULT_FILE = "./reports/trust_scores.json"
REPUTATION_RESULT_FILE = "./reports/reputation_scores.json"

def extract_aircraft_data():
    file_name = "./scripts/reduced_aircraft_data.json"
    with open(file_name, 'r') as f:
        data = json.load(f)
        data = data["call"]
    
    return data


def setup_configuration():
    # Deploy contract
    account = get_account(0)
    if network.show_active() == "development":
        aircraft_details = deploy_aircraft_database()
        time.sleep(1)
    else:
        aircraft_details = AircraftDatabase[-1]

    # Set configuration parameters
    aircraft_details.setParameters(
        TOTAL_ACCOUNTS, 
        TOTAL_MALICIOUS_ACCOUNTS, 
        ERRONEOUS_AIRCRAFT, 
        REPUTATION_ALGORITHM)

    # Open the trust file as write to erase previous contents
    with open(TRUST_RESULT_FILE, "w") as f:
        pass

    # Open the reputation file as write to erase previous contents
    with open(REPUTATION_RESULT_FILE, "w") as f:
        pass

    return aircraft_details


def submit_data(data, aircraft_details):
    # List to store all dictionaries
    trust_scores_data = []
    reputation_scores_data = []

    # Submit data for each account
    # 1st - Select 1 epoch
    for epoch_index, epoch in enumerate(data):
        if epoch_index >= TOTAL_EPOCHS: break
        
        # Print the epoch information 
        print("#######################")
        print(f"\tEpoch {epoch_index}")
        print("#######################")
        epoch_time = epoch["time"]

        # 3rd - Submit the aircraft states per account
        for account_index in range(0, TOTAL_ACCOUNTS):
            account = get_account(account_index)

            icao24 = []
            longitude = []
            latitude = []
            on_ground = []
            geo_altitude = []
            velocity = []
            true_track = []
            vertical_rate = []

            aircraft_count = 0
            # 2nd - Select each aircraft present in the epoch
            for aircraft in epoch["states"]:
                if aircraft_count >= TOTAL_AIRCRAFT: break
                else: aircraft_count += 1

                icao24.append(aircraft["icao24"])
                longitude.append(aircraft["longitude"] * 1e4)
                latitude.append(aircraft["latitude"] * 1e4)
                on_ground.append(aircraft["on_ground"])
                geo_altitude.append(int(aircraft["geo_altitude"] * 1e2))
                velocity.append(int(aircraft["velocity"] * 1e2))
                true_track.append(int(aircraft["true_track"] * 1e2))
                vertical_rate.append(int(aircraft["vertical_rate"] * 1e2))
            
            transaction = aircraft_details.submitAircraftData(
                icao24, epoch_time, longitude, latitude, geo_altitude, on_ground, velocity, true_track, vertical_rate, {"from": account}
            )

        # Store trust scores before starting the new epoch
        if epoch_index > 0:
            store_trust_scores(aircraft_details, epoch_index, trust_scores_data)
            store_reputation_data(aircraft_details, epoch_index, reputation_scores_data)

    # Submit dummy data for an extra iteration to compute trust and reputation for the last epoch
    account = get_account(0)
    dummy_icao24 = ["000000"]
    dummy_epoch_time = 0
    dummy_values = [0] * len(dummy_icao24)
    aircraft_details.submitAircraftData(
        dummy_icao24, dummy_epoch_time, dummy_values, dummy_values, dummy_values, dummy_values, dummy_values, dummy_values, dummy_values, {"from": account}
    )
    store_trust_scores(aircraft_details, epoch_index, trust_scores_data)
    store_reputation_data(aircraft_details, epoch_index, reputation_scores_data)

    # Wait 1 second before finishing to avoid any errors  
    transaction.wait(1)

    # Write trust score values result to file
    with open(TRUST_RESULT_FILE, "a") as f:
        json.dump(trust_scores_data, f, indent=4)

    with open(REPUTATION_RESULT_FILE, "a") as f:
        json.dump(reputation_scores_data, f, indent=4)


def store_trust_scores(aircraft_details, epoch_index, trust_scores_data):
    contributors = aircraft_details.getContributorList()
    epoch_trust_scores = {
        "epoch": epoch_index,
        "trust_scores": []
    }

    for i in range(len(contributors)):
        for j in range(i + 1, len(contributors)):
            trust_scores = aircraft_details.getTrustScores(contributors[i], contributors[j])
            epoch_trust_scores["trust_scores"].append({
                "pair": (f"Contributor {i+1}", f"Contributor {j+1}"),
                "trust_scores": trust_scores
            })

    trust_scores_data.append(epoch_trust_scores)  


def store_reputation_data(aircraft_details, epoch_index, reputation_scores_data):
    contributors = aircraft_details.getContributorList()
    epoch_reputation_scores = {
        "epoch": epoch_index,
        "reputation_scores": []
    }

    for i in range(len(contributors)):
        epoch_reputation_scores["reputation_scores"].append({
            "Account number": i+1,
            "Address": contributors[i],
            "Reputation": aircraft_details.getReputationScore(contributors[i])
        })

    reputation_scores_data.append(epoch_reputation_scores)


def main():
    # Obtain the list of epochs and their information
    data = extract_aircraft_data()

    start_time = time.time()
    # Submit to the smart contract
    aircraft_details = setup_configuration()
    submit_data(data, aircraft_details)
    end_time = time.time()
    total_time = end_time - start_time

    print(f"Total execution time: {total_time} seconds")

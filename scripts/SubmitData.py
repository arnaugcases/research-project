from brownie import AircraftDatabase, accounts, network, config, exceptions
from scripts.Deploy import deploy_aircraft_dabase
from scripts.helpful_scripts import get_account
import json
import numpy as np
import time

TOTAL_ACCOUNTS = 5
TOTAL_EPOCHS = 5
TOTAL_AIRCRAFT = 5

def extract_aircraft_data():
    file_name = "./scripts/reduced_aircraft_data.json"
    with open(file_name, 'r') as f:
        data = json.load(f)
        data = data["call"]
    
    return data


def submit_data(data):
    # Deploy contract
    account = get_account(0)
    if network.show_active() == "development":
        aircraft_details = deploy_aircraft_dabase()
        time.sleep(1)
    else:
        aircraft_details = AircraftDatabase[-1]

    # Submit data for each account
    # 1st - Select 1 epoch
    epoch_count = 0
    for epoch in data:
        if epoch_count >= TOTAL_EPOCHS: break
        else: epoch_count += 1
        print(f"Epoch {epoch_count}")
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

    # Wait 1 second before finishing to avoid any errors  
    transaction.wait(1)

    # Return contract
    return aircraft_details


def read_parameters(aircraft_details):
    # Get list of contributors
    contributors = aircraft_details.getContributorList()
    print(f"List of contributors:\n {contributors}")

    # Get list of aircraft
    aircraft_list = aircraft_details.getAircraftList()
    print(f"Aircraft list:\n {aircraft_list}")


def main():
    # Obtain the list of epochs and their information
    data = extract_aircraft_data()

    start_time = time.time()
    # Submit to the smart contract
    aircraft_details = submit_data(data)
    end_time = time.time()
    total_time = end_time - start_time

    print(f"Total execution time: {total_time} seconds")

    # Extract information from the smart contract
    read_parameters(aircraft_details)

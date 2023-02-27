from brownie import AircraftDatabase, accounts, network, config, exceptions
from scripts.Deploy import deploy_aircraft_dabase
from scripts.helpful_scripts import get_account
import json
import numpy as np
import time

TOTAL_ACCOUNTS = 1

def extract_aircraft_data():

    file_name = "./scripts/aircraft_data.json"
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

    # Submit data
    for epoch in data:
        epoch_time = epoch["time"]

        keys_to_check = ["icao24", "longitude", "latitude", "on_ground", "velocity", "true_track"]

        for aircraft in epoch["states"]:
            if any(aircraft[key] is None for key in keys_to_check):
                continue

            icao24 = aircraft["icao24"]
            longitude = int(aircraft["longitude"] * 1e4)
            latitude = int(aircraft["latitude"] * 1e4)
            on_ground = aircraft["on_ground"]
            geo_altitude = 0 if on_ground else int(aircraft["geo_altitude"] * 1e2)
            velocity = int(aircraft["velocity"] * 1e2)
            true_track = int(aircraft["true_track"] * 1e2)
            vertical_rate = 0 if on_ground else int(aircraft["vertical_rate"] * 1e2)
            
            transaction = aircraft_details.submitAircraftData(
                icao24, epoch_time, longitude, latitude, geo_altitude, on_ground, velocity, true_track, vertical_rate, {"from": account}
            )
        
    transaction.wait(1)


    # Return contract
    return aircraft_details

def main():
    # Obtain the list of epochs and their information
    data = extract_aircraft_data()

    # Submit to the smart contract
    aircraft_details = submit_data(data)

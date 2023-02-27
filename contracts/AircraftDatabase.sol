// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract AircraftDatabase {
    // Struct for storing the last known information about an aircraft
    struct Aircraft {
        int256 longitude;
        int256 latitude;
        uint256 geoAltitude;
        bool onGround;
        uint256 velocity;
        uint256 trueTrack;
        int16 verticalRate;
    }

    // Mapping that relates each icao24 identifier to a mapping of epochs and their associated data
    mapping(bytes6 => mapping(uint256 => Aircraft)) public aircraftData;

    // Mapping that relates each icao24 identifier to an array of epochs for which data is available
    mapping(bytes6 => uint256[]) public aircraftEpochs;

    // Array storing all the aircraft for which the smart contract has data
    bytes6[] public aircraftList;

    // Function for adding aircraft data for a specific epoch
    function submitAircraftData(
        bytes6 _icao24,
        uint256 _epoch,
        int256 _longitude,
        int256 _latitude,
        uint256 _geoAltitude,
        bool _onGround,
        uint256 _velocity,
        uint256 _trueTrack,
        int16 _verticalRate
    ) public {
        // Add the specified aircraft data to the aircraftData mapping for the specified epoch
        aircraftData[_icao24][_epoch] = Aircraft({
            longitude: _longitude,
            latitude: _latitude,
            geoAltitude: _geoAltitude,
            onGround: _onGround,
            velocity: _velocity,
            trueTrack: _trueTrack,
            verticalRate: _verticalRate
        });

        // If the aircraft is not already in the aircraftList array, add it
        if (!containsAircraft(_icao24)) {
            aircraftList.push(_icao24);
        }

        // If the epoch is not already in the aircraftEpochs mapping for the specified aircraft, add it
        if (!containsEpoch(_icao24, _epoch)) {
            aircraftEpochs[_icao24].push(_epoch);
        }
    }

    // Function to check if an aircraft is already in the aircraftList array
    function containsAircraft(bytes6 _icao24) public view returns (bool) {
        for (uint256 i = 0; i < aircraftList.length; i++) {
            if (aircraftList[i] == _icao24) {
                return true;
            }
        }
        return false;
    }

    // Function to check if an epoch is already in the aircraftEpochs mapping for the specified aircraft
    function containsEpoch(bytes6 _icao24, uint256 _epoch)
        public
        view
        returns (bool)
    {
        uint256[] memory epochs = aircraftEpochs[_icao24];
        for (uint256 i = 0; i < epochs.length; i++) {
            if (epochs[i] == _epoch) {
                return true;
            }
        }
        return false;
    }
}

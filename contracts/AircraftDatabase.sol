// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./StateEstimation.sol";
import "./Reputation.sol";

contract AircraftDatabase {
    /* 
    ---------------------------------
            Public Variables 
    ---------------------------------
    */
    // Most recent information about an aircraft
    struct AircraftStateVector {
        int24 longitude;
        int24 latitude;
        uint24 geoAltitude;
        bool onGround;
        int24 velocity;
        int24 trueTrack;
        int16 verticalRate;
        uint32 timestamp;
    }

    // Structure mapping of a given Aircraft ICAO24 identifier
    mapping(bytes3 => AircraftStateVector) public aircraftInfo;

    // Array storing all the aircraft icao24 identifier for which the smart contract has data
    bytes3[] public aircraftList;

    // Mapping to check if there is information on an aircraft
    mapping(bytes3 => bool) public isAircraftInfoAvailable;

    // List of contributors that submitted information for aircraft
    address[] public listOfContributors;

    // Mapping to check if the address has already contributed
    mapping(address => bool) public addressContributed;

    // Reputation scores (0-100) for each contributor
    mapping(address => uint8) public reputationScore;

    // Structure to store the new values for a given aircraft
    struct AircraftStateOccurrences {
        int24[] longitude;
        int24[] latitude;
        uint24[] geoAltitude;
        bool[] onGround;
        int24[] velocity;
        int24[] trueTrack;
        int16[] verticalRate;
    }

    mapping(bytes3 => AircraftStateOccurrences) aircraftOccurrences;

    // List of all aircraft submitted at current epoch
    bytes3[] aircraftListCurrentEpoch;

    mapping(bytes3 => bool) public isAircraftInCurrentEpoch;

    uint32 private currentEpoch;

    // Function for adding aircraft data for a specific epoch
    function submitAircraftData(
        bytes3 _icao24,
        uint32 _epoch,
        int24 _longitude,
        int24 _latitude,
        uint24 _geoAltitude,
        bool _onGround,
        int24 _velocity,
        int24 _trueTrack,
        int16 _verticalRate
    ) public {
        // If the aircraft is not already in the aircraftList array, add it
        if (!isAircraftInfoAvailable[_icao24]) {
            isAircraftInfoAvailable[_icao24] = true;
            aircraftList.push(_icao24);
        }

        // Add the sender to the list of contributors
        if (!addressContributed[msg.sender]) {
            addressContributed[msg.sender] = true;
            listOfContributors.push(msg.sender);
        }

        // Update the occurrences structure if it is for the same epoch
        if (currentEpoch == 0 || currentEpoch == _epoch) {
            // Update list of aircraft in current epoch
            if (!isAircraftInCurrentEpoch[_icao24]) {
                isAircraftInCurrentEpoch[_icao24] = true;
                aircraftListCurrentEpoch.push(_icao24);
            }
        } else if (currentEpoch != _epoch) {
            // The information is for a new epoch

            // 1st - Compute the state estimation for the aircraft
            computeEstimates();

            // 2nd - Compute trust scores

            // 3rd - Compute reputation scores

            // Delete the values of the variables from the previous epoch
            resetEpochVariables();
        }

        // Add values to the occurrence structure
        aircraftOccurrences[_icao24].longitude.push(_longitude);
        aircraftOccurrences[_icao24].latitude.push(_latitude);
        aircraftOccurrences[_icao24].geoAltitude.push(_geoAltitude);
        aircraftOccurrences[_icao24].onGround.push(_onGround);
        aircraftOccurrences[_icao24].velocity.push(_velocity);
        aircraftOccurrences[_icao24].trueTrack.push(_trueTrack);
        aircraftOccurrences[_icao24].verticalRate.push(_verticalRate);

        // Update current epoch
        currentEpoch = _epoch;
    }

    /* 
        PRIVATE functions (to modify data)
    */
    function computeEstimates() private {
        /* Iterate through each aircraft in epoch and compute its estimate,
           based on the values for the current epoch and the previous estimate.
        */
        for (uint i = 0; i < aircraftListCurrentEpoch.length; i++) {}
    }

    function resetEpochVariables() private {
        for (uint i = 0; i < aircraftListCurrentEpoch.length; i++) {
            // Delete the values of the structure containing the occurrences
            delete aircraftOccurrences[aircraftListCurrentEpoch[i]];

            // Delete the values of the mapping
            delete isAircraftInCurrentEpoch[aircraftListCurrentEpoch[i]];
        }

        // Delete the list of aircraft in current epoch
        delete aircraftListCurrentEpoch;
    }

    /* 
        VIEW functions (get data)
    */
    function getAircraftList() public view returns (bytes3[] memory) {
        return aircraftList;
    }

    function getContributorList() public view returns (address[] memory) {
        return listOfContributors;
    }
}

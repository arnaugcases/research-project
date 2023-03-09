// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract AircraftDatabase {
    /* 
    ---------------------------------
            Public Variables 
    ---------------------------------
    */
    // Most recent information about an aircraft
    struct AircraftStateVector {
        int256 longitude;
        int256 latitude;
        uint256 geoAltitude;
        bool onGround;
        uint256 velocity;
        uint256 trueTrack;
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
        int256[] longitude;
        int256[] latitude;
        uint256[] geoAltitude;
        bool[] onGround;
        uint256[] velocity;
        uint256[] trueTrack;
        int16[] verticalRate;
    }

    mapping(bytes3 => AircraftStateOccurrences) aircraftOccurrences;

    // List of all aircraft submitted at current epoch
    bytes3[] aircraftListCurrentEpoch;

    // Function for adding aircraft data for a specific epoch
    function submitAircraftData(
        bytes3 _icao24,
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

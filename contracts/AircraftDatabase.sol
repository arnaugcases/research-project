// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./StateEstimation.sol";
import "./Reputation.sol";

contract AircraftDatabase {
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
    mapping(address => uint) public reputationScore;

    // Malicious contributor
    mapping(address => bool) isMaliciousContributor;

    // Information on trust scores of a given contributor
    mapping(address => mapping(address => uint8[])) private trustScores;

    // Check if the contributor submitted in current epoch
    mapping(address => bool) public contributorInCurrentEpoch;

    // List of contributors in current epoch
    address[] public listOfContributorsInCurrentEpoch;

    // Structure to store the new values for a given aircraft
    struct AircraftStateOccurrences {
        int24 longitude;
        int24 latitude;
        uint24 geoAltitude;
        bool onGround;
        int24 velocity;
        int24 trueTrack;
        int16 verticalRate;
        address contributor;
    }

    mapping(bytes3 => AircraftStateOccurrences[]) aircraftOccurrences;

    // List of all aircraft submitted at current epoch
    bytes3[] aircraftListCurrentEpoch;

    mapping(bytes3 => bool) public isAircraftInCurrentEpoch;

    uint32 public currentEpoch;

    // Configuration variables
    uint8 private numberOfContributors;
    uint8 private numberOfMaliciousContributors;
    uint8 private erroenousAircraft;
    uint8 private reputationAlgorithm;
    bool private reputationFirstRun = true;

    // Function for adding aircraft data for a specific epoch
    function submitAircraftData(
        bytes3[] memory _icao24,
        uint32 _epoch,
        int24[] memory _longitude,
        int24[] memory _latitude,
        uint24[] memory _geoAltitude,
        bool[] memory _onGround,
        int24[] memory _velocity,
        int24[] memory _trueTrack,
        int16[] memory _verticalRate
    ) public {
        address contributor = msg.sender;
        // Add the sender to the list of contributors
        if (!addressContributed[contributor]) {
            addressContributed[contributor] = true;
            listOfContributors.push(contributor);
        }

        // Set the malicious contributor to the first one that sends data
        if (
            !isMaliciousContributor[contributor] &&
            numberOfMaliciousContributors > 0
        ) {
            isMaliciousContributor[contributor] = true;
            numberOfMaliciousContributors -= 1;
        }

        // Actions to take for a new epoch (but not the first call to the function)
        if (currentEpoch != _epoch && currentEpoch != 0) {
            // The information is for a new epoch

            // 1st - Compute the state estimation for the aircraft
            //computeEstimates();

            // 2nd - Compute trust scores
            computeTrustScores();

            // 3rd - Compute reputation scores
            computeReputationScores();

            // Delete the values of the variables from the previous epoch
            resetEpochVariables();
        }

        // Update list of aircraft in current epoch
        for (uint i = 0; i < _icao24.length; i++) {
            if (!isAircraftInCurrentEpoch[_icao24[i]]) {
                isAircraftInCurrentEpoch[_icao24[i]] = true;
                aircraftListCurrentEpoch.push(_icao24[i]);
            }
        }

        // Add contributor to the list of contributos in current epoch
        if (!contributorInCurrentEpoch[contributor]) {
            contributorInCurrentEpoch[contributor] = true;
            listOfContributorsInCurrentEpoch.push(contributor);
        }

        // Add values to the occurrence structure
        for (uint i = 0; i < _icao24.length; i++) {
            aircraftOccurrences[_icao24[i]].push(
                AircraftStateOccurrences(
                    _longitude[i],
                    _latitude[i],
                    _geoAltitude[i],
                    _onGround[i],
                    _velocity[i],
                    _trueTrack[i],
                    _verticalRate[i],
                    contributor
                )
            );

            // If the aircraft is not already in the aircraftList array, add it. This is for all epochs.
            if (!isAircraftInfoAvailable[_icao24[i]]) {
                isAircraftInfoAvailable[_icao24[i]] = true;
                aircraftList.push(_icao24[i]);
            }
        }

        // Update current epoch
        currentEpoch = _epoch;
    }

    /* 
        PRIVATE functions (to modify data)
    */
    function computeEstimates() internal {
        /* Iterate through each aircraft in epoch and compute its estimate,
           based on the values for the current epoch and the previous estimate.
        */
        bytes3 aircraftId;
        AircraftStateVector memory estimatedState;
        for (uint i = 0; i < aircraftListCurrentEpoch.length; i++) {
            aircraftId = aircraftListCurrentEpoch[0];
            estimatedState = StateEstimation.computeEstimates(
                aircraftOccurrences[aircraftId],
                currentEpoch
            );
            aircraftInfo[aircraftId] = estimatedState;
        }
    }

    function computeTrustScores() internal {
        for (uint i = 0; i < listOfContributorsInCurrentEpoch.length; i++) {
            address contributor1 = listOfContributorsInCurrentEpoch[i];
            for (
                uint j = i + 1;
                j < listOfContributorsInCurrentEpoch.length;
                j++
            ) {
                address contributor2 = listOfContributorsInCurrentEpoch[j];

                // Determine the order of the contributor addresses
                address smallerContributor = contributor1 < contributor2
                    ? contributor1
                    : contributor2;
                address largerContributor = contributor1 < contributor2
                    ? contributor2
                    : contributor1;

                // Clear previous epoch trust scores
                delete trustScores[smallerContributor][largerContributor];

                uint8 erroenousAircraftAvailable = erroenousAircraft;

                for (uint k = 0; k < aircraftListCurrentEpoch.length; k++) {
                    // If both contributors are malicious or good, they will have
                    // a high trust value between them. Only if one is malicious
                    // and the other one not will they have a lower trust value.abi
                    // Lower trust values are assigned for the total of erroneous data
                    if (
                        (isMaliciousContributor[smallerContributor] !=
                            isMaliciousContributor[largerContributor]) &&
                        erroenousAircraftAvailable > 0
                    ) {
                        trustScores[smallerContributor][largerContributor].push(
                                randomNumberInRange(
                                    1,
                                    20,
                                    (i + 1) * (j + 1) * (k + 1)
                                )
                            );
                        erroenousAircraftAvailable -= 1;
                    } else {
                        trustScores[smallerContributor][largerContributor].push(
                                randomNumberInRange(
                                    80,
                                    100,
                                    (i + 1) * (j + 1) * (k + 1)
                                )
                            );
                    }
                }
            }
        }
    }

    function computeReputationScores() internal {
        uint numOfContributorsEpoch = listOfContributorsInCurrentEpoch.length;
        uint[] memory currentReputationScores = new uint[](
            numOfContributorsEpoch
        );

        for (uint i = 0; i < numOfContributorsEpoch; i++) {
            address contributor = listOfContributorsInCurrentEpoch[i];
            currentReputationScores[i] = reputationScore[contributor];
            // If it is the first time being called, initialize all reputation
            // scores to 100 / N, where N = number of contributors
            if (reputationFirstRun)
                currentReputationScores[i] += 100 / numOfContributorsEpoch;
        }
        reputationFirstRun = false;

        uint[] memory updatedReputationScores = Reputation
            .computeReputationScores(
                trustScores,
                listOfContributorsInCurrentEpoch,
                currentReputationScores,
                reputationAlgorithm
            );

        for (uint i = 0; i < numOfContributorsEpoch; i++) {
            address contributor = listOfContributorsInCurrentEpoch[i];
            reputationScore[contributor] = updatedReputationScores[i];
        }
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

        for (uint i = 0; i < listOfContributorsInCurrentEpoch.length; i++) {
            delete contributorInCurrentEpoch[
                listOfContributorsInCurrentEpoch[i]
            ];
        }

        delete listOfContributorsInCurrentEpoch;
    }

    // Contract setter function
    function setParameters(
        uint8 _numberOfContributors,
        uint8 _numberOfMaliciousContributors,
        uint8 _erroneousAircraft,
        uint8 _reputationAlgorithm
    ) public {
        numberOfContributors = _numberOfContributors;
        numberOfMaliciousContributors = _numberOfMaliciousContributors;
        erroenousAircraft = _erroneousAircraft;
        reputationAlgorithm = _reputationAlgorithm;
    }

    /* 
        Contract getter functions
    */
    function getCurrentEpoch() public view returns (uint32) {
        return currentEpoch;
    }

    function getAircraftList() public view returns (bytes3[] memory) {
        return aircraftList;
    }

    function getContributorList() public view returns (address[] memory) {
        return listOfContributors;
    }

    function getAircraftState(
        bytes3 _aicraftId
    ) public view returns (AircraftStateVector memory) {
        return aircraftInfo[_aicraftId];
    }

    function getTrustScores(
        address contributor1,
        address contributor2
    ) public view returns (uint8[] memory) {
        require(contributor1 != contributor2, "Contributors must be different");

        address smallerContributor = contributor1 < contributor2
            ? contributor1
            : contributor2;
        address largerContributor = contributor1 < contributor2
            ? contributor2
            : contributor1;

        return trustScores[smallerContributor][largerContributor];
    }

    function getReputationScore(
        address contributor
    ) public view returns (uint) {
        return reputationScore[contributor];
    }

    /* 
    Helper functions
    */
    // Helper function to generate random number in a given range
    function randomNumberInRange(
        uint8 min,
        uint8 max,
        uint randNonce
    ) private view returns (uint8) {
        uint8 randomNum = uint8(
            (uint256(
                keccak256(
                    abi.encodePacked(
                        block.timestamp,
                        block.difficulty,
                        randNonce
                    )
                )
            ) % (max - min + 1)) + min
        );
        return randomNum;
    }
}

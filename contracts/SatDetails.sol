// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./Median.sol";

contract SatDetails {
    uint24[] satIds;
    mapping(uint24 => bool) satIdSubmitted;
    /*
     * Structure preserving the final information of the satellite
     */
    struct satDetailsStruct {
        uint24 satId; // Satellite number
        uint32 apogee; // apogee in meters
        uint32 perigee; // perigee in meters
        uint32 inclination; // inclination * 10
        uint32 launchDate; // Number of seconds since 4 octobre 1957 00:00 am (launch day of Sputnik 1)
    }

    // Map ID to satellite
    mapping(uint24 => satDetailsStruct) satDetailsMapping;

    // Structure to store all values submitted for a given satellite id
    struct satOccurences {
        uint32[] inclinationOcc;
        uint32[] apogeeOcc;
        uint32[] perigeeOcc;
        address[] observer; // observer that submitted the data
    }

    // Maps satellite to occurences
    mapping(uint24 => satOccurences) satOccurenceMapping;

    // Structure to store score values
    struct reputationStruct {
        uint8[] scores;
        mapping(uint24 => uint8) scoreIndex;
        mapping(uint24 => bool) satIdScoreExist;
    }

    // Map address to trust and reputation scores
    mapping(address => uint8) reputationMapping;
    mapping(address => reputationStruct) scoresMapping;

    function submitSatDetails(
        uint24 _satId,
        uint32 _inclination,
        uint32 _apogee,
        uint32 _perigee
    ) public {
        satOccurenceMapping[_satId].inclinationOcc.push(_inclination);
        satOccurenceMapping[_satId].apogeeOcc.push(_apogee);
        satOccurenceMapping[_satId].perigeeOcc.push(_perigee);
        satOccurenceMapping[_satId].observer.push(msg.sender);

        if (satIdSubmitted[_satId] == false) {
            satIdSubmitted[_satId] == true;
            satIds.push(_satId);
        }

        if (satOccurenceMapping[_satId].observer.length >= 3) {
            consensusSatDetails(_satId);
            //computeTrustScores(_satId);
            //computeReputation();
        }
    }

    // Compute the consensus for a given satellite
    function consensusSatDetails(uint24 _satId) internal {
        satDetailsMapping[_satId].apogee = Median.calculateInplace(
            satOccurenceMapping[_satId].apogeeOcc
        );
        satDetailsMapping[_satId].perigee = Median.calculateInplace(
            satOccurenceMapping[_satId].perigeeOcc
        );
        satDetailsMapping[_satId].inclination = Median.calculateInplace(
            satOccurenceMapping[_satId].inclinationOcc
        );
    }

    // Compute the trust and reputation scores
    function computeTrustScores(uint24 _satId) internal {
        int32 inclination;
        int32 apogee;
        int32 perigee;
        uint8 trustScore;
        int32 inclinationError;
        int32 apogeeError;
        int32 perigeeError;
        uint8 satScoreArrayIndex;

        int32 consensusInclination = int32(
            satDetailsMapping[_satId].inclination
        );
        int32 consensusApogee = int32(satDetailsMapping[_satId].apogee);
        int32 consensusPerigee = int32(satDetailsMapping[_satId].perigee);

        for (
            uint8 i = 0;
            i < satOccurenceMapping[_satId].observer.length;
            i++
        ) {
            inclination = int32(satOccurenceMapping[_satId].inclinationOcc[i]);
            apogee = int32(satOccurenceMapping[_satId].apogeeOcc[i]);
            perigee = int32(satOccurenceMapping[_satId].perigeeOcc[i]);

            inclinationError =
                ((inclination - consensusInclination) * 100) /
                consensusInclination; // From 0 to 100
            inclinationError = inclinationError < 0
                ? -inclinationError
                : inclinationError;

            apogeeError = ((apogee - consensusApogee) * 100) / consensusApogee;
            apogeeError = apogeeError < 0 ? -apogeeError : apogeeError;

            perigeeError =
                ((perigee - consensusPerigee) * 100) /
                consensusPerigee;
            perigeeError = perigeeError < 0 ? -perigeeError : perigeeError;

            trustScore =
                100 -
                uint8(uint32(inclinationError + apogeeError + perigeeError));

            address obs = satOccurenceMapping[_satId].observer[i];

            if (scoresMapping[obs].satIdScoreExist[_satId] == false) {
                scoresMapping[obs].satIdScoreExist[_satId] = true;
                scoresMapping[obs].scores.push(trustScore);
                scoresMapping[obs].scoreIndex[_satId] = uint8(
                    scoresMapping[obs].scores.length - 1
                );
            } else {
                scoresMapping[obs].scores[
                    scoresMapping[obs].scoreIndex[_satId]
                ] = trustScore;
            }
        }
    }

    // Computes the reputation of an observer
    function computeReputation() internal {
        uint8 reputation;
        uint16 totalReputation;
        uint8 scores;
        for (uint8 i = 0; i < satIds.length; i++) {
            if (scoresMapping[msg.sender].satIdScoreExist[satIds[i]]) {
                reputation = scoresMapping[msg.sender].scores[
                    scoresMapping[msg.sender].scoreIndex[satIds[i]]
                ];
                scores += 1;
                totalReputation += reputation;
            }
        }

        reputation = uint8(totalReputation / scores);

        reputationMapping[msg.sender] = reputation;
    }

    /*
     * Returns the consensus on a satellite
     */
    function viewSatDetails(uint24 _satId)
        public
        view
        returns (
            uint24 satId,
            uint32 inclination,
            uint32 apogee,
            uint32 perigee
        )
    {
        satId = _satId;
        inclination = satDetailsMapping[_satId].inclination;
        apogee = satDetailsMapping[_satId].apogee;
        perigee = satDetailsMapping[_satId].perigee;
    }

    /*
     * Returns the trust scores for a given address
     */
    function viewReputation()
        public
        view
        returns (uint8[] memory scores, uint8 reputation)
    {
        scores = scoresMapping[msg.sender].scores;
        reputation = reputationMapping[msg.sender];
    }
}

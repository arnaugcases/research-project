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

    // Events
    event trustScoreComputed(uint24 satId, uint8[] iteration);

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
            computeTrustScores(_satId);
            computeReputation();
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
        uint8 trustScore = 50;
        uint8 satIndex;
        uint8 totalError;
        address obs;
        uint8[] memory iterations = new uint8[](
            satOccurenceMapping[_satId].observer.length
        );

        for (
            uint8 i = 0;
            i < satOccurenceMapping[_satId].observer.length;
            i++
        ) {
            totalError = computeOrbitError(_satId, i);
            iterations[i] = i;

            //trustScore = totalError > 100 ? 0 : 100 - totalError;
            trustScore = i;

            obs = satOccurenceMapping[_satId].observer[i];

            scoresMapping[obs].scores.push(trustScore);

            // if (scoresMapping[obs].satIdScoreExist[_satId] == false) {
            //     scoresMapping[obs].scores.push(trustScore);
            //     satIndex = uint8(scoresMapping[obs].scores.length - 1);
            //     scoresMapping[obs].scoreIndex[_satId] = satIndex;
            //     scoresMapping[obs].satIdScoreExist[_satId] = true;
            // } else {
            //     scoresMapping[obs].scores[
            //         scoresMapping[obs].scoreIndex[_satId]
            //     ] = trustScore;
            // }
        }
        emit trustScoreComputed(_satId, iterations);
    }

    // This function computes the error between orbits
    function computeOrbitError(uint24 _satId, uint8 _i)
        internal
        view
        returns (uint8)
    {
        int32 consensusInclination = int32(
            satDetailsMapping[_satId].inclination
        );
        int32 consensusApogee = int32(satDetailsMapping[_satId].apogee);
        int32 consensusPerigee = int32(satDetailsMapping[_satId].perigee);

        int32 inclination = int32(
            satOccurenceMapping[_satId].inclinationOcc[_i]
        );
        int32 apogee = int32(satOccurenceMapping[_satId].apogeeOcc[_i]);
        int32 perigee = int32(satOccurenceMapping[_satId].perigeeOcc[_i]);

        int32 inclinationError = ((inclination - consensusInclination) * 100) /
            consensusInclination;
        inclinationError = inclinationError < 0
            ? -inclinationError
            : inclinationError;

        int32 apogeeError = ((apogee - consensusApogee) * 100) /
            consensusApogee;
        apogeeError = apogeeError < 0 ? -apogeeError : apogeeError;

        int32 perigeeError = ((perigee - consensusPerigee) * 100) /
            consensusPerigee;
        perigeeError = perigeeError < 0 ? -perigeeError : perigeeError;

        return uint8(uint32(inclinationError + apogeeError + perigeeError));
    }

    // Computes the reputation of an observer
    function computeReputation() internal {
        uint8 reputation;
        uint16 totalReputation;
        uint16 scores;
        for (uint8 i = 0; i < satIds.length; i++) {
            if (scoresMapping[msg.sender].satIdScoreExist[satIds[i]]) {
                reputation = scoresMapping[msg.sender].scores[
                    scoresMapping[msg.sender].scoreIndex[satIds[i]]
                ];
                scores += 1;
                totalReputation += reputation;
            }
        }

        //reputation = uint8(totalReputation / scores);

        reputationMapping[msg.sender] = 0;
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

    // Returns the satellite occurences
    function viewSatOccurences(uint24 _satId)
        public
        view
        returns (
            uint32[] memory inclinationOcc,
            uint32[] memory apogeeOcc,
            uint32[] memory perigeeOcc,
            address[] memory observer
        )
    {
        inclinationOcc = satOccurenceMapping[_satId].inclinationOcc;
        apogeeOcc = satOccurenceMapping[_satId].apogeeOcc;
        perigeeOcc = satOccurenceMapping[_satId].perigeeOcc;
        observer = satOccurenceMapping[_satId].observer;
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

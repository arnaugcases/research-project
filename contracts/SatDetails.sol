// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./Median.sol";

contract SatDetails {
    uint24[] satIds;
    mapping(uint24 => bool) satIdSubmitted;

    address[] observers;
    mapping(address => bool) observerExists;
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

    // Map address to the satellite it has submitted
    mapping(address => uint24[]) satSubmittedMapping;

    // Structure to store trust scores
    struct trustScoreStruct {
        mapping(uint24 => uint8) sat2trustMapping;
        uint8 reputation;
    }

    // Mapping from address to trust scores
    mapping(address => trustScoreStruct) trustMapping;

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

        satSubmittedMapping[msg.sender].push(_satId);

        if (satIdSubmitted[_satId] == false) {
            satIdSubmitted[_satId] == true;
            satIds.push(_satId);
        }

        if (observerExists[msg.sender] == false) {
            observerExists[msg.sender] = true;
            observers.push(msg.sender);
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
        uint256 trustScore;
        uint256 totalError;
        address obs;
        address[] memory observers = new address[](
            satOccurenceMapping[_satId].observer.length
        );
        for (
            uint8 i = 0;
            i < satOccurenceMapping[_satId].observer.length;
            i++
        ) {
            totalError = computeOrbitError(_satId, i);

            trustScore = totalError > 1000 ? 0 : (1000 - totalError) / 10;

            obs = satOccurenceMapping[_satId].observer[i];
            observers[i] = obs;

            trustMapping[obs].sat2trustMapping[_satId] = uint8(trustScore);
        }
    }

    // This function computes the error between orbits
    function computeOrbitError(uint24 _satId, uint8 _i)
        internal
        view
        returns (uint256)
    {
        uint256 consensusInclination = satDetailsMapping[_satId].inclination;
        uint256 consensusApogee = satDetailsMapping[_satId].apogee;
        uint256 consensusPerigee = satDetailsMapping[_satId].perigee;

        uint256 inclination = satOccurenceMapping[_satId].inclinationOcc[_i];
        uint256 apogee = satOccurenceMapping[_satId].apogeeOcc[_i];
        uint256 perigee = satOccurenceMapping[_satId].perigeeOcc[_i];

        uint256 inclinationError = inclination < consensusInclination
            ? (consensusInclination - inclination)**2
            : (inclination - consensusInclination)**2;

        uint256 apogeeError = apogee < consensusApogee
            ? (consensusApogee - apogee)**2
            : (apogee - consensusApogee)**2;

        uint256 perigeeError = perigee < consensusPerigee
            ? (consensusPerigee - perigee)**2
            : (perigee - consensusPerigee)**2;

        uint256 totalError = (inclinationError + apogeeError + perigeeError) /
            3;
        return sqrt(totalError);
    }

    // Computes the reputation of an observer
    function computeReputation() internal {
        uint16 scores;
        address obs;

        for (uint8 i = 0; i < observers.length; i++) {
            obs = observers[i];
            scores = 0;

            for (uint8 j = 0; j < satSubmittedMapping[obs].length; j++) {
                scores += trustMapping[obs].sat2trustMapping[
                    satSubmittedMapping[obs][j]
                ];
            }

            trustMapping[obs].reputation = uint8(
                scores / satSubmittedMapping[obs].length
            );
        }
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
        scores = new uint8[](satSubmittedMapping[msg.sender].length);
        uint24 satId;
        for (uint8 i = 0; i < satSubmittedMapping[msg.sender].length; i++) {
            satId = satSubmittedMapping[msg.sender][i];
            scores[i] = trustMapping[msg.sender].sat2trustMapping[satId];
        }
        reputation = trustMapping[msg.sender].reputation;
    }

    // Returns the satellite submitted by the sender address
    function viewSatSubmitted() public view returns (uint24[] memory sats) {
        sats = satSubmittedMapping[msg.sender];
    }

    function sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}

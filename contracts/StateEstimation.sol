// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./AircraftDatabase.sol";

library StateEstimation {
    function computeEstimates(
        AircraftDatabase.AircraftStateOccurrences[] memory occurrences,
        uint32 currentEpoch
    )
        public
        pure
        returns (AircraftDatabase.AircraftStateVector memory estimatedState)
    {
        // Dummy function, just returns the values of the first array element
        estimatedState = AircraftDatabase.AircraftStateVector(
            occurrences[0].longitude,
            occurrences[0].latitude,
            occurrences[0].geoAltitude,
            occurrences[0].onGround,
            occurrences[0].velocity,
            occurrences[0].trueTrack,
            occurrences[0].verticalRate,
            currentEpoch
        );

        return estimatedState;
    }
}

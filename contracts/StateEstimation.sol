// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./AircraftDatabase.sol";

library StateEstimation {
    function computeEstimates(
        AircraftDatabase.AircraftStateOccurrences[] memory observations,
        uint32 currentEpoch
    )
        public
        pure
        returns (AircraftDatabase.AircraftStateVector memory trueValue)
    {
    uint24 N = uint24(observations.length);

    require(observations[0].onGround == false);   // plane needs to be flying

        trueValue = AircraftDatabase.AircraftStateVector(
            0,
            0,
            observations[0].geoAltitude,
            observations[0].onGround,
            0,
            0,
            observations[0].verticalRate,
            currentEpoch
        );

    int24 sumLongitude;
    int24 sumLatitude;
    int24 sumVelocity;
    int24 sumTrueTrack;
    for (uint24 i = 0; i < N; i++) {
        sumLongitude += observations[i].longitude;
        sumLatitude += observations[i].latitude;
        sumVelocity += observations[i].velocity;
        sumTrueTrack += observations[i].trueTrack;
    }
    
    trueValue.longitude = sumLongitude/int24(N);
    trueValue.latitude = sumLatitude/int24(N);
    trueValue.velocity = sumVelocity/int24(N);
    trueValue.trueTrack = sumTrueTrack/int24(N);
    
    return trueValue;
    }


struct Error {
int longitude;
int latitude;
int velocity;
int trueTrack;
}

function observationError(AircraftDatabase.AircraftStateVector[] memory observations, AircraftDatabase.AircraftStateVector memory trueValue, int errorAllowed) public  pure returns(int[] memory){
    
     uint N = observations.length;

    Error[] memory abs_error = new Error[](N);
     for (uint256 i = 0; i < N; i++) {
        abs_error[i].longitude = (observations[i].longitude > trueValue.longitude) ? observations[i].longitude - trueValue.longitude : trueValue.longitude - observations[i].longitude;
        abs_error[i].latitude = (observations[i].latitude > trueValue.latitude) ? observations[i].latitude - trueValue.latitude : trueValue.latitude - observations[i].latitude;
        abs_error[i].velocity = (observations[i].velocity > trueValue.velocity) ? observations[i].velocity - trueValue.velocity : trueValue.velocity - observations[i].velocity;
        abs_error[i].trueTrack = (observations[i].trueTrack > trueValue.trueTrack) ? observations[i].trueTrack - trueValue.trueTrack : trueValue.trueTrack - observations[i].trueTrack;

    }

    Error memory max_error;

    Error[] memory final_error = new Error[](N);

    //For the next part we need to work with non-negative values
    trueValue.longitude = (trueValue.longitude > 0) ? trueValue.longitude : trueValue.longitude*(-1);
    trueValue.latitude = (trueValue.latitude > 0) ? trueValue.latitude : trueValue.latitude*(-1);
 
    for (uint16 i = 0; i < N; i++) {
        if (abs_error[i].longitude > errorAllowed * trueValue.longitude/10) {
            final_error[i].longitude = 1000;
            abs_error[i].longitude = 0;
            }
        if (abs_error[i].latitude > errorAllowed * trueValue.latitude/10) {
            final_error[i].latitude = 1000;
            abs_error[i].latitude = 0;
    }
        if (abs_error[i].velocity > errorAllowed * trueValue.velocity/10) {
            final_error[i].velocity = 1000;
            abs_error[i].velocity = 0;
    }
        if (abs_error[i].trueTrack > errorAllowed * trueValue.trueTrack/10) {
            final_error[i].trueTrack = 1000;
            abs_error[i].trueTrack = 0;
    }
    


        if (max_error.longitude <= abs_error[i].longitude) {
                max_error.longitude = abs_error[i].longitude;
            }
        if (max_error.latitude <= abs_error[i].latitude) {
                max_error.latitude = abs_error[i].latitude;
            }
        if (max_error.velocity <= abs_error[i].velocity) {
                max_error.velocity = abs_error[i].velocity;
            }
        if (max_error.trueTrack <= abs_error[i].trueTrack) {
                max_error.trueTrack = abs_error[i].trueTrack;
            }
    }

    for (uint16 i = 0; i < N; i++) {
        if (final_error[i].longitude == 0) {
            final_error[i].longitude = int(abs_error[i].longitude*1000/max_error.longitude);
        }
        if (final_error[i].latitude == 0) {
            final_error[i].latitude = int(abs_error[i].latitude*1000/max_error.latitude);
        }
        if (final_error[i].velocity == 0) {
            final_error[i].velocity = int(abs_error[i].velocity*1000/max_error.velocity);
        }
        if (final_error[i].trueTrack == 0) {
            final_error[i].trueTrack = int(abs_error[i].trueTrack*1000/max_error.trueTrack);
        }
    }
    

    int[] memory _final_error = new int[](N);
    for (uint256 i = 0; i < N; i++) {
         _final_error[i] = (final_error[i].longitude+final_error[i].latitude+final_error[i].velocity+final_error[i].trueTrack)/4;

    }

    return _final_error;
}

}
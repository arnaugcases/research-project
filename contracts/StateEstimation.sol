// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./AircraftDatabase.sol";

import "./Trigonometry.sol";

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

        require(observations[0].onGround == false); // plane needs to be flying

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

        trueValue.longitude = sumLongitude / int24(N);
        trueValue.latitude = sumLatitude / int24(N);
        trueValue.velocity = sumVelocity / int24(N);
        trueValue.trueTrack = sumTrueTrack / int24(N);

        return trueValue;
    }

    struct Error {
        int longitude;
        int latitude;
        int velocity;
        int trueTrack;
    }

    function observationError(
        AircraftDatabase.AircraftStateOccurrences[] memory observations,
        AircraftDatabase.AircraftStateVector memory trueValue,
        int errorAllowed
    ) public pure returns (int[] memory) {

        uint N = observations.length;

        Error[] memory abs_error = new Error[](N);
        for (uint256 i = 0; i < N; i++) {
            abs_error[i].longitude = (observations[i].longitude >
                trueValue.longitude)
                ? observations[i].longitude - trueValue.longitude
                : trueValue.longitude - observations[i].longitude;

            abs_error[i].latitude = (observations[i].latitude >
                trueValue.latitude)
                ? observations[i].latitude - trueValue.latitude
                : trueValue.latitude - observations[i].latitude;

            abs_error[i].velocity = (observations[i].velocity >
                trueValue.velocity)
                ? observations[i].velocity - trueValue.velocity
                : trueValue.velocity - observations[i].velocity;

            abs_error[i].trueTrack = (observations[i].trueTrack >
                trueValue.trueTrack)
                ? observations[i].trueTrack - trueValue.trueTrack
                : trueValue.trueTrack - observations[i].trueTrack;
        }

        Error memory max_error;

        Error[] memory final_error = new Error[](N);

        //For the next part we need to work with non-negative values
        trueValue.longitude = (trueValue.longitude > 0)
            ? trueValue.longitude
            : trueValue.longitude * (-1);
        trueValue.latitude = (trueValue.latitude > 0)
            ? trueValue.latitude
            : trueValue.latitude * (-1);

        for (uint16 i = 0; i < N; i++) {
            if (
                abs_error[i].longitude >
                (errorAllowed * trueValue.longitude) / 10
            ) {
                final_error[i].longitude = 1000;
                abs_error[i].longitude = 0;
            }
            if (
                abs_error[i].latitude > (errorAllowed * trueValue.latitude) / 10
            ) {
                final_error[i].latitude = 1000;
                abs_error[i].latitude = 0;
            }
            if (
                abs_error[i].velocity > (errorAllowed * trueValue.velocity) / 10
            ) {
                final_error[i].velocity = 1000;
                abs_error[i].velocity = 0;
            }
            if (
                abs_error[i].trueTrack >
                (errorAllowed * trueValue.trueTrack) / 10
            ) {
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
                final_error[i].longitude = int(
                    (abs_error[i].longitude * 1000) / max_error.longitude
                );
            }
            if (final_error[i].latitude == 0) {
                final_error[i].latitude = int(
                    (abs_error[i].latitude * 1000) / max_error.latitude
                );
            }
            if (final_error[i].velocity == 0) {
                final_error[i].velocity = int(
                    (abs_error[i].velocity * 1000) / max_error.velocity
                );
            }
            if (final_error[i].trueTrack == 0) {
                final_error[i].trueTrack = int(
                    (abs_error[i].trueTrack * 1000) / max_error.trueTrack
                );
            }
        }

        int[] memory _final_error = new int[](N);
        for (uint256 i = 0; i < N; i++) {
            _final_error[i] =
                (final_error[i].longitude +
                    final_error[i].latitude +
                    final_error[i].velocity +
                    final_error[i].trueTrack) /
                4;
        }

        return _final_error;
    }

    function trueValueFromObservationsEnhanced(
        AircraftDatabase.AircraftStateOccurrences[] memory observations,
        uint32 currentEpoch,
        AircraftDatabase.AircraftStateVector memory previous_val
    ) public pure returns (AircraftDatabase.AircraftStateVector memory) {

        AircraftDatabase.AircraftStateVector
            memory obs_val_current = computeEstimates(
                observations,
                currentEpoch
            );

        // Prediction part next

        AircraftDatabase.AircraftStateVector memory trueValue = obs_val_current;

        int24 delta_t = int24(
            uint24(
                (obs_val_current.timestamp > previous_val.timestamp)
                    ? obs_val_current.timestamp - previous_val.timestamp
                    : previous_val.timestamp - obs_val_current.timestamp
            )
        );

        if (delta_t > 900) {
            return trueValue;
        }

        int24[] memory prediction = position_prediction_improved(delta_t, previous_val); //[0] - longitude, [1] - latitude

    /*
	Calculating prediction validity:
	Assuming planes fly in straight lines (strong assumption I know), the velocity 
	and trueTrack should be the same in obs1 and obs2 - or at least close to
	each other, given the time interval between observations is small. Taking the 
	values of obs 2 (more recent) as 'true' values, the difference 
	between these values and those in in obs1 (older) determined the accuracy/
	validity of the prediction components. 
    */

        int24 velocity_offset = previous_val.velocity > obs_val_current.velocity
            ? ((previous_val.velocity - obs_val_current.velocity) * 1000) /
                previous_val.velocity
            : ((obs_val_current.velocity - previous_val.velocity) * 1000) /
                obs_val_current.velocity;

        int24 track_offset = previous_val.trueTrack > obs_val_current.trueTrack
            ? ((previous_val.trueTrack - obs_val_current.trueTrack) * 1000) /
                previous_val.trueTrack
            : ((obs_val_current.trueTrack - previous_val.trueTrack) * 1000) /
                obs_val_current.trueTrack;
        //offset value 0-1000

        int gain = 2000 - int(track_offset) - int(velocity_offset);

        trueValue.longitude = int24(
            (1000 *
                int(obs_val_current.longitude) +
                int(prediction[0]) *
                gain) / (1000 + gain)
        );
        trueValue.latitude = int24(
            (1000 * int(obs_val_current.latitude) + int(prediction[1] * gain)) /
                (1000 + gain)
        );

   return trueValue;

}



    function position_prediction(
        int24 _delta_time,
        AircraftDatabase.AircraftStateVector memory previous_estimate
    ) pure internal returns (int24[] memory) {


    int24  Re = 6371; //km
    int24  pi = 31415; //km

    int24[] memory data = new int24[](4);

    //altitude assumed in metres, velocity ms-1, delta_t seconds, result - delta_hor - is in km*1000

    //sin*100, velocity *100, scale *100
    data[2] = int24(
        int(
            Trigonometry.sin(uint16(int16(int(previous_estimate.trueTrack)*16384/360/100))))
            /328*previous_estimate.velocity*_delta_time/1000
            *(Re*100/(Re+int24(previous_estimate.geoAltitude)/100000))
            *100/(2*int(Re)*int(pi))*360);
    data[3] = int24(
        int(
            Trigonometry.sin(uint16(int16(int(90*100-previous_estimate.trueTrack)*16384/360/100))))
            /328*previous_estimate.velocity*_delta_time/1000
            *(Re*100/(Re+int24(previous_estimate.geoAltitude)/100000))
            *100/(2*int(Re)*int(pi))*360);
	data[0] = previous_estimate.longitude+data[2]; //assumes angle in deg*10000.  longitude
    data[1] = previous_estimate.latitude+data[3]; //latitude


    return data;
}

function position_prediction_improved(
    int24 _delta_time,
    AircraftDatabase.AircraftStateVector memory previous_estimate)
    pure internal returns(int24[] memory) {

    int24  Re = 6371; //km

    int  pi = 31415; //pi*10000
    
    int d = int(_delta_time)*int(previous_estimate.velocity)/100000; //km

    int24[] memory data = new int24[](4);

    if (previous_estimate.longitude<0){
        previous_estimate.longitude += 360*10000;
    }

    if (previous_estimate.latitude<0){
        previous_estimate.latitude += 360*10000;
    }

    //altitude assumed in metres, velocity ms-1, delta_t seconds, result - delta_hor - is in km*1000
    //trigonometry factor *100, scale factor *10. Pi*10000 -> resulting angle in deg*10000
    //assumes angle in deg*10000

    int sin_lat1 = int(Trigonometry.sin(uint16(int16(int(previous_estimate.latitude)*16384/360/10000))))*10000/32767; //range +-10000

    int cos_lat1 = int(Trigonometry.sin(uint16(int16(int(90*10000-previous_estimate.latitude)*16384/360/10000))))*10000/32767; //range +-10000

    int DoverR = int(d)*1000/int(Re);//  d/R * 1000

    int sin_track = int(Trigonometry.sin(uint16(int16(int(previous_estimate.trueTrack)*16384/360/100))))*10000/32767; //range +-10000

    int cos_track = int(Trigonometry.sin(uint16(int16(int(90*100-previous_estimate.trueTrack)*16384/360/100))))*10000/32767; //range +-10000

    data[1] = int24(asin(((sin_lat1*1000*10000+cos_lat1*DoverR*cos_track)/10000000))*1800000/pi); //deg*10000 latitude

    data[2] = (data[1] < 0) ? data[1] + 360*10000 : data[1];   // need a latitude angle in the range 0-360 deg

    data[3] = previous_estimate.longitude + int24(atan(sin_track*DoverR*cos_lat1*10/(1*10000*10000-sin_lat1
    *int(Trigonometry.sin(uint16(int16(int(data[1])*16384/360/10000))))*10000/32767))*1800000/pi);   //longitude in deg*10000
   
    data[0] = (data[3] > 1800000) ? data[3] - 360*10000 : data[3];  //longitude range [-180, 180]
    
    return data;
}

function asin(int256 x) public pure returns (int256) {   // input range +-10000, returns angle in radians*10000
    int divider = 10000;
    return x+x**3/6/divider**2+x**5*3/40/divider**4+15*x**7/(336*divider**6)+105*x**9/(3456*divider**8)+945*x**11/(42240*divider**10)+x**13*10395/(599040*divider**12);
}

function atan(int256 x)
public pure returns (int256) {
    // input range +-10000, returns angle in radians*10000
    int divider = 10000;

    return x - x**3/3/divider**2+x**5/5/divider**4-x**7/7/divider**6;
}

}
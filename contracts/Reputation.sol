// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library Reputation {
    function computeReputationScores(
        mapping(address => mapping(address => uint8[])) storage trustScores,
        address[] memory listOfContributorsInCurrentEpoch,
        uint[] memory currentReputationScores,
        uint8 reputationAlgorithm
    ) public view returns (uint[] memory) {
        uint[] memory updatedReputationScores = new uint[](
            currentReputationScores.length
        );

        uint nbOfContributors = listOfContributorsInCurrentEpoch.length;
        uint reputation;

        // The structure for both simple and weighted averages is the same
        if (reputationAlgorithm <= 1) {
            address contributor1;

            for (uint i = 0; i < nbOfContributors; i++) {
                contributor1 = listOfContributorsInCurrentEpoch[i];

                if (reputationAlgorithm == 0) {
                    reputation = simpleAverage(
                        currentReputationScores[i],
                        nbOfContributors,
                        listOfContributorsInCurrentEpoch,
                        contributor1,
                        trustScores
                    );
                } else if (reputationAlgorithm == 1) {
                    reputation = weightedAverage(
                        currentReputationScores[i],
                        nbOfContributors,
                        listOfContributorsInCurrentEpoch,
                        contributor1,
                        trustScores
                    );
                }

                updatedReputationScores[i] = reputation;
            }
        }

        return updatedReputationScores;
    }

    function simpleAverage(
        uint currentReputation,
        uint nbOfContributors,
        address[] memory listOfContributorsInCurrentEpoch,
        address contributor1,
        mapping(address => mapping(address => uint8[])) storage trustScores
    ) private view returns (uint updatedReputation) {
        uint totalTrust = 0;
        uint averageTrust = 0;
        uint numberOfTrustValues = 0;

        for (uint j = 0; j < nbOfContributors; j++) {
            address contributor2 = listOfContributorsInCurrentEpoch[j];
            if (contributor1 != contributor2) {
                // Order them so that the first one is the lowest one
                address smallerContributor = contributor1 < contributor2
                    ? contributor1
                    : contributor2;
                address largerContributor = contributor1 < contributor2
                    ? contributor2
                    : contributor1;

                totalTrust += sum(
                    trustScores[smallerContributor][largerContributor]
                );
                numberOfTrustValues += trustScores[smallerContributor][
                    largerContributor
                ].length;
            }
        }

        averageTrust = totalTrust / numberOfTrustValues;

        updatedReputation =
            ((10000 / currentReputation) *
                currentReputation +
                (10000 / averageTrust) *
                averageTrust) /
            (10000 / currentReputation + 10000 / averageTrust);
    }

    function weightedAverage(
        uint currentReputation,
        uint nbOfContributors,
        address[] memory listOfContributorsInCurrentEpoch,
        address contributor1,
        mapping(address => mapping(address => uint8[])) storage trustScores
    ) private view returns (uint updatedReputation) {
        uint weightedAverageTrust = 0;
        uint logSum = 0;
        uint numberOfTrustValues = 0;
        uint8[] memory list;

        for (uint j = 0; j < nbOfContributors; j++) {
            address contributor2 = listOfContributorsInCurrentEpoch[j];
            if (contributor1 != contributor2) {
                // Order them so that the first one is the lowest one
                address smallerContributor = contributor1 < contributor2
                    ? contributor1
                    : contributor2;
                address largerContributor = contributor1 < contributor2
                    ? contributor2
                    : contributor1;

                list = trustScores[smallerContributor][largerContributor];

                for (uint k = 0; k < list.length; k++) {
                    logSum += log2(uint(list[k]) ** 16);
                    numberOfTrustValues += 1;
                }
            }
        }

        // Obtain the average of the log values
        logSum = logSum / numberOfTrustValues;

        // Convert again into the original value
        weightedAverageTrust = 2 ** (logSum / 16);

        updatedReputation =
            ((10000 / currentReputation) *
                currentReputation +
                (10000 / weightedAverageTrust) *
                weightedAverageTrust) /
            (10000 / currentReputation + 10000 / weightedAverageTrust);
    }

    // Utility functions
    function sum(uint8[] memory list) private pure returns (uint) {
        uint totalSum = 0;

        for (uint i = 0; i < list.length; i++) {
            totalSum += list[i];
        }

        return totalSum;
    }

    function log2(uint x) private pure returns (uint y) {
        assembly {
            let arg := x
            x := sub(x, 1)
            x := or(x, div(x, 0x02))
            x := or(x, div(x, 0x04))
            x := or(x, div(x, 0x10))
            x := or(x, div(x, 0x100))
            x := or(x, div(x, 0x10000))
            x := or(x, div(x, 0x100000000))
            x := or(x, div(x, 0x10000000000000000))
            x := or(x, div(x, 0x100000000000000000000000000000000))
            x := add(x, 1)
            let m := mload(0x40)
            mstore(
                m,
                0xf8f9cbfae6cc78fbefe7cdc3a1793dfcf4f0e8bbd8cec470b6a28a7a5a3e1efd
            )
            mstore(
                add(m, 0x20),
                0xf5ecf1b3e9debc68e1d9cfabc5997135bfb7a7a3938b7b606b5b4b3f2f1f0ffe
            )
            mstore(
                add(m, 0x40),
                0xf6e4ed9ff2d6b458eadcdf97bd91692de2d4da8fd2d0ac50c6ae9a8272523616
            )
            mstore(
                add(m, 0x60),
                0xc8c0b887b0a8a4489c948c7f847c6125746c645c544c444038302820181008ff
            )
            mstore(
                add(m, 0x80),
                0xf7cae577eec2a03cf3bad76fb589591debb2dd67e0aa9834bea6925f6a4a2e0e
            )
            mstore(
                add(m, 0xa0),
                0xe39ed557db96902cd38ed14fad815115c786af479b7e83247363534337271707
            )
            mstore(
                add(m, 0xc0),
                0xc976c13bb96e881cb166a933a55e490d9d56952b8d4e801485467d2362422606
            )
            mstore(
                add(m, 0xe0),
                0x753a6d1b65325d0c552a4d1345224105391a310b29122104190a110309020100
            )
            mstore(0x40, add(m, 0x100))
            let
                magic
            := 0x818283848586878898a8b8c8d8e8f929395969799a9b9d9e9faaeb6bedeeff
            let
                shift
            := 0x100000000000000000000000000000000000000000000000000000000000000
            let a := div(mul(x, magic), shift)
            y := div(mload(add(m, sub(255, a))), shift)
            y := add(
                y,
                mul(
                    256,
                    gt(
                        arg,
                        0x8000000000000000000000000000000000000000000000000000000000000000
                    )
                )
            )
        }
    }

    function nthRoot(uint256 value, uint256 n) public pure returns (uint256) {
        require(n > 0 && (n & (n - 1)) == 0, "N must be a power of 2");

        if (value == 0) {
            return 0;
        }

        uint256 x = value;
        uint256 y = (x + 1) >> 1;
        uint256 shift = 0;

        // Find the position of the most significant bit
        while (x >> shift != 0) {
            shift++;
        }

        // Adjust the shift to the nearest even number
        if (shift % 2 != 0) {
            shift--;
        }

        // Apply the binary search method
        while (shift >= 2) {
            x = y;
            y = (x + (value >> (shift - n))) >> 1;
            shift -= n;
        }

        return y;
    }
}

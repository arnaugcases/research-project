// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library Reputation {
    function computeReputationScores(
        mapping(address => mapping(address => uint8[])) storage trustScores,
        address[] memory listOfContributorsInCurrentEpoch,
        uint8[] memory currentReputationScores,
        uint8 reputationAlgorithm
    ) public view returns (uint8[] memory) {
        uint8[] memory updatedReputationScores = new uint8[](
            currentReputationScores.length
        );

        uint nbOfContributors = listOfContributorsInCurrentEpoch.length;

        // Select different reputation algorithms
        if (reputationAlgorithm == 0) {
            for (uint i = 0; i < nbOfContributors; i++) {
                address contributor1 = listOfContributorsInCurrentEpoch[i];
                uint averageTrust = 0;
                uint alpha = 50;

                for (uint j = 0; j < nbOfContributors; j++) {
                    address contributor2 = listOfContributorsInCurrentEpoch[j];
                    if (i != j) {
                        // Order them so that the first one is the lowest one
                        (contributor1, contributor2) = contributor1 <
                            contributor2
                            ? (contributor1, contributor2)
                            : (contributor2, contributor1);

                        averageTrust = average(
                            trustScores[contributor1][contributor2],
                            averageTrust
                        );
                    }
                }

                updatedReputationScores[i] = uint8(
                    (alpha * currentReputationScores[i]) /
                        100 +
                        ((100 - alpha) * averageTrust) /
                        100
                );
            }
        }

        return updatedReputationScores;
    }

    function average(
        uint8[] memory list,
        uint averageTrust
    ) private pure returns (uint) {
        uint totalSum = 0;

        for (uint i = 0; i < list.length; i++) {
            totalSum += list[i];
        }

        return (totalSum / list.length + averageTrust) / 2;
    }
}

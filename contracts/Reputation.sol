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

        // Select different reputation algorithms
        if (reputationAlgorithm == 0) {
            address contributor1;
            address contributor2;

            for (uint i = 0; i < nbOfContributors; i++) {
                contributor1 = listOfContributorsInCurrentEpoch[i];
                uint averageTrust = 0;
                uint alpha = 50;

                for (uint j = 0; j < nbOfContributors; j++) {
                    contributor2 = listOfContributorsInCurrentEpoch[j];
                    if (i != j) {
                        // Order them so that the first one is the lowest one
                        address smallerContributor = contributor1 < contributor2
                            ? contributor1
                            : contributor2;
                        address largerContributor = contributor1 < contributor2
                            ? contributor2
                            : contributor1;

                        averageTrust += average(
                            trustScores[smallerContributor][largerContributor]
                        );
                    }
                }

                updatedReputationScores[i] = averageTrust;
            }
        }

        return updatedReputationScores;
    }

    function average(uint8[] memory list) private pure returns (uint) {
        uint totalSum = 0;

        for (uint i = 0; i < list.length; i++) {
            totalSum += list[i];
        }

        return (totalSum);
    }
}

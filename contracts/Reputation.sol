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
        uint numerator;
        uint denominator;
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
                    numerator += (uint(10000) / list[k]) * list[k];
                    denominator += uint(10000) / list[k];
                }
            }
        }

        weightedAverageTrust = numerator / denominator;

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
}

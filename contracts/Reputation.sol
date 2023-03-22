// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library Reputation {
    function computeReputationScores(
        mapping(address => mapping(address => uint8[])) storage trustScores,
        address[] memory listOfContributorsInCurrentEpoch,
        uint[] memory currentReputationScores,
        uint8 reputationAlgorithm,
        uint8 averageWeight
    ) public view returns (uint[] memory) {
        uint[] memory updatedReputationScores = new uint[](
            currentReputationScores.length
        );

        uint nbOfContributors = listOfContributorsInCurrentEpoch.length;
        uint reputation;

        // Select different reputation algorithms
        if (reputationAlgorithm == 0) {
            address contributor1;

            for (uint i = 0; i < nbOfContributors; i++) {
                contributor1 = listOfContributorsInCurrentEpoch[i];

                reputation = simpleAverage(
                    currentReputationScores[i],
                    nbOfContributors,
                    listOfContributorsInCurrentEpoch,
                    contributor1,
                    trustScores,
                    averageWeight
                );

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
        mapping(address => mapping(address => uint8[])) storage trustScores,
        uint alpha
    ) private view returns (uint updatedReputation) {
        uint totalTrust = 0;
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

        updatedReputation =
            (alpha * currentReputation) /
            100 +
            ((100 - alpha) * (totalTrust / numberOfTrustValues)) /
            100;
    }

    function sum(uint8[] memory list) private pure returns (uint) {
        uint totalSum = 0;

        for (uint i = 0; i < list.length; i++) {
            totalSum += list[i];
        }

        return totalSum;
    }
}

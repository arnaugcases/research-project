import json
import matplotlib.pyplot as plt
from math import log2
import numpy as np
import random

TRUST_RESULT_FILE = "./reports/trust_scores.json"
REPUTATION_ALGORITHM = 2

# Load the JSON file
with open(TRUST_RESULT_FILE, "r") as f:
    data = json.load(f)

# Extract epochs and reputation scores
epochs = []

contributors = 5 # Looking directly at the file
contributor_reputations = {i: [int(100/5)] for i in range(1, contributors+1)}
trust_values = {}

############################################
#       REPUTATION ALGORITHMS              #
############################################
def simple_average(i, previous_reputation):
    total_trust = 0
    total_trust_values = 0
    for j in range(1, contributors+1):
        if i != j:
            pair = (i, j) if i < j else (j, i)
            total_trust += sum(trust_values[pair])
            total_trust_values += len(trust_values[pair])
    
    # Divisions performed as in solidity
    average_trust = total_trust // total_trust_values

    return int(weighted_sum(previous_reputation, average_trust))


def weighted_average(i, previous_reputation):
    log_sum = 0
    total_trust_values = 0
    average_trust = 0
    for j in range(1, contributors+1):
        if i != j:
            pair = (i, j) if i < j else (j, i)
            list = trust_values[pair]

            log_sum += sum([int(log2(x ** 16)) for x in list])
            total_trust_values += len(list)
    
    # Divisions performed as in solidity
    average_trust = log_sum // total_trust_values

    # Convert to the original
    weighted_average_trust = int(2 ** (average_trust // 16))

    return int(weighted_sum(previous_reputation, weighted_average_trust))


def eigen_trust(previous_reputation):
    # Create the trust matrix
    n = contributors
    trust_matrix = np.zeros((n, n))
    for pair, values in trust_values.items():
        i = pair[0]-1
        j = pair[1]-1

        trust_matrix[i, j] = np.mean(values)
        trust_matrix[j, i] = np.mean(values)

    np.fill_diagonal(trust_matrix, 100)

    for i in range(0, len(trust_matrix)):
        row_sum = sum(trust_matrix[i][:]) 
        for j in range(0, len(trust_matrix)):
            trust_matrix[i,j] /= row_sum


    # Initialize the trust vector
    trust_vector = np.ones(n) / n
    trust_vector = previous_reputation

    # Iterate until convergence
    alpha = 0.5 # Damping factor
    for i in range(1000):
        new_trust_vector = alpha * np.dot(trust_matrix.transpose(), trust_vector) + (1 - alpha) / n
        
        trust_vector = new_trust_vector

    return trust_vector


def weighted_sum(x, y):
    return (1/x * x + 1/y * y) / (1/x + 1/y)


def weighted_sum2(new_trust, previous_trust):
    alpha = 0.8
    return alpha*previous_trust + (1-alpha)*new_trust


############################################
#       REPUTATION CALCULATION             #
############################################

# Initialize reputation for eigentrust
previous_reputation = np.ones(contributors)/contributors

if REPUTATION_ALGORITHM == 2:
    for i in range(1, contributors+1):
        contributor_reputations[i] = [1/contributors]

for record in data:
    epoch = record["epoch"]
    epochs.append(epoch)

    for trust_info in record["trust_scores"]:
        pair = trust_info["pair"]
        pair = (int(pair[0][-1]), int(pair[1][-1]))
        trust_values[pair] = trust_info["trust_scores"]
    
    # Reputation algorithm
    if REPUTATION_ALGORITHM <= 1:
        for i in range(1, contributors+1):

            if REPUTATION_ALGORITHM == 0:
                reputation = simple_average(i, contributor_reputations[i][-1])
            elif REPUTATION_ALGORITHM == 1:
                reputation = weighted_average(i, contributor_reputations[i][-1])
                
            contributor_reputations[i].append(reputation)
    elif REPUTATION_ALGORITHM == 2:
        previous_reputation = eigen_trust(previous_reputation)

        for index, x in enumerate(previous_reputation):
            contributor_reputations[index+1].append(weighted_sum2(x, contributor_reputations[index+1][-1]))

# Plot the data
fig, ax = plt.subplots()
for account_number, reputations in contributor_reputations.items():
    ax.plot(epochs, reputations[1:], label=f"Contributor {account_number}")

ax.set_xlabel("Epoch number")
ax.set_ylabel("Reputation score")
ax.legend(bbox_to_anchor=(0.5, 1.1), loc='upper center', borderaxespad=0., ncol = 5, fontsize = 10)
ax.grid(which="major", alpha=0.5)
ax.xaxis.set_major_locator(plt.MaxNLocator(integer=True))
fig.set_size_inches(10,7)

ax.yaxis.set_minor_locator(plt.MultipleLocator(5))
ax.grid(which='minor', alpha=0.25)

# Show the plot
plt.show()
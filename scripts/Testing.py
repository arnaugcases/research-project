import json
import matplotlib.pyplot as plt

TRUST_RESULT_FILE = "./reports/trust_scores.json"

# Load the JSON file
with open(TRUST_RESULT_FILE, "r") as f:
    data = json.load(f)

# Extract epochs and reputation scores
epochs = []

contributors = 5 # Looking directly at the file
contributor_reputations = {i: [int(100/5)] for i in range(1, contributors+1)}
trust_values = {}

def simple_average(i, previous_reputation):
    total_trust = 0
    total_trust_values = 0
    for j in range(1, contributors+1):
        if i != j:
            pair = (i, j) if i < j else (j, i)
            total_trust += sum(trust_values[pair])
            total_trust_values += len(trust_values[pair])
    
    average_trust = total_trust / total_trust_values

    return int((1/previous_reputation * previous_reputation + 1/average_trust * average_trust) / 
               (1/previous_reputation + 1/average_trust))


for record in data:
    epoch = record["epoch"]
    epochs.append(epoch)

    for trust_info in record["trust_scores"]:
        pair = trust_info["pair"]
        pair = (int(pair[0][-1]), int(pair[1][-1]))
        trust_values[pair] = trust_info["trust_scores"]
    
    # Reputation algorithm
    for i in range(1, contributors+1):
        reputation = simple_average(i, contributor_reputations[i][-1])
        contributor_reputations[i].append(reputation)


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
import json
import matplotlib.pyplot as plt

REPUTATION_RESULT_FILE = "./reports/reputation_scores.json"
GRAPH_FILENAME = "./reports/figures/reputation_scores.eps"

# Load the JSON file
with open(REPUTATION_RESULT_FILE, "r") as f:
    data = json.load(f)

# Extract epochs and reputation scores
epochs = []
account_reputations = {}

for record in data:
    epoch = record["epoch"]
    epochs.append(epoch)

    for reputation_info in record["reputation_scores"]:
        account_number = reputation_info["Account number"]
        reputation = reputation_info["Reputation"]

        if account_number not in account_reputations:
            account_reputations[account_number] = []

        account_reputations[account_number].append(reputation)

# Plot the data
fig, ax = plt.subplots()
for account_number, reputations in account_reputations.items():
    ax.plot(epochs, reputations, label=f"Contributor {account_number}")

ax.set_xlabel("Epoch number")
ax.set_ylabel("Reputation score")
ax.legend(bbox_to_anchor=(0.5, 1.1), loc='upper center', borderaxespad=0., ncol = 5, fontsize = 10)
ax.grid(which="major", alpha=0.5)
ax.xaxis.set_major_locator(plt.MaxNLocator(integer=True))
fig.set_size_inches(10,7)

ax.yaxis.set_minor_locator(plt.MultipleLocator(5))
ax.grid(which='minor', alpha=0.25)

# Save the figure in EPS format
plt.savefig(GRAPH_FILENAME, format="eps", bbox_inches='tight')

# Show the plot
plt.show()
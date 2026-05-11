import os
import cantera as ct
import matplotlib.pyplot as plt
import matplotlib as mpl

# Configure matplotlib for transparent SVG with theme-aware styling
mpl.rcParams.update({
    "figure.facecolor": "none",
    "axes.facecolor": "none",
    "savefig.facecolor": "none",
    "svg.fonttype": "none",
})

import random, sys
from adjustText import adjust_text

masterpath = os.environ.get("ATLASDIR")
if masterpath is None:
    print("ATLAS environment variable is not set.")
    sys.exit(1)
datapath = masterpath + '/database/'
ct.add_directory(datapath+'Chemistry')

folder_path = datapath+'Chemistry'

# Mechanisms to exclude
exclude_mechs = ['JLR-frassoldati-ct.yaml', 'JLR-nasuti-ct.yaml']

# Initialize lists to store data
species_counts = []
reaction_counts = []
mechanism_names = []

# Loop through each file in the folder
for file_name in os.listdir(folder_path):
    if file_name.endswith('.yaml'):
        file_path = os.path.join(folder_path, file_name)
        
        try:
            # Load the mechanism file
            gas = ct.Solution(file_path)
            
            # Get the phase name
            phase_name = gas.name
            
            if any(exclude in file_path for exclude in exclude_mechs):
                continue

            
            # Get species and reactions count
            species_count = gas.n_species
            reaction_count = gas.n_reactions
            
            # Append the data
            species_counts.append(species_count)
            reaction_counts.append(reaction_count)
            mechanism_names.append(phase_name)
            
        except Exception as e:
            print(f"Error loading {file_name}: {e}")

# Plotting

# Generate random symbols and colors for each mechanism
markers = ['o', 's', 'D', '^', 'v', '<', '>', 'p', '*', 'h', 'H', 'x', '+']
colors = ['b', 'g', 'r', 'c', 'm', 'y', 'k']

plt.figure(figsize=(10, 7))
texts = []

for i in range(len(mechanism_names)):
    marker = random.choice(markers)
    color = random.choice(colors)
    
    plt.scatter(species_counts[i], reaction_counts[i], marker=marker, color=color)
    
    # Store text objects for later adjustment
    texts.append(plt.text(species_counts[i], reaction_counts[i], mechanism_names[i], fontsize=10))

# Labels and title
plt.xlabel('Number of Species')
plt.ylabel('Number of Reactions')
plt.grid(True, alpha=0.5)
plt.xscale('log')
plt.yscale('log')

# Automatically adjust text to avoid overlaps
adjust_text(texts, arrowprops=dict(arrowstyle='-', color='gray'))

# Save and show
plt.savefig('resume.svg', dpi=300, bbox_inches='tight', transparent=True)
plt.show()
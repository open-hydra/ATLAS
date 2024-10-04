import numpy as np
import random
import matplotlib.pyplot as plt

# List of possible line styles, colors, and markers
line_styles = ['-', '--', '-.', ':']
markers = ['o', 's', 'd', '^', 'v', '>', '<', 'p', '*']

# Random style generator function
def get_random_style():
    return {
        'linestyle': random.choice(line_styles),
        'marker': random.choice(markers),
        'markersize': 6
    }

def plot_1D(models, x, y, xlabel, ylabel, logy):

    random_styles = {}  # Store random styles for models not in 'styles'
    for model in models:
        random_styles[model] = get_random_style()  # Store the random style for reuse   
        random_style = random_styles[model]
        plt.plot(x, y[model],
            label=model,  # Label the model by its name
            linestyle=random_style['linestyle'], 
            marker=random_style['marker'], 
            markersize=random_style['markersize'])
    plt.xlabel(xlabel)
    plt.ylabel(ylabel)
    plt.legend(loc='best')
    if (logy): plt.yscale('log')


def plot_2D(mixture_ratio, pressure, Ta):
    import matplotlib.pyplot as plt
    """
    Plots the adiabatic flame temperature (Tad) as a 3D surface for each model on the same plot.
    
    Parameters:
        mixture_ratio (list or array): The mixture ratios (x-axis).
        pressure (list or array): The pressures (y-axis).
        Ta (dict): A dictionary containing the temperature data for each model.
                   Each entry Ta[model] is a list of temperatures for that model.
    """
    from mpl_toolkits.mplot3d import Axes3D
    # Convert mixture_ratio and pressure to numpy arrays for meshgrid creation
    mr_array = np.array(mixture_ratio)
    p_array = np.array(pressure)

    # Create a meshgrid for plotting
    X, Y = np.meshgrid(mr_array, p_array)

    # Create a figure and a 3D axis
    fig = plt.figure()
    ax = fig.add_subplot(111, projection='3d')

    # Plot a surface for each model in the Ta dictionary
    for model_name, temperatures in Ta.items():
        # Reshape the temperature data to match the grid shape
        Tad = np.array(temperatures).reshape(len(mixture_ratio), len(pressure))

        # Plot the surface for the current model
        ax.plot_surface(X, Y, Tad.T, label=model_name, alpha=0.6)  # 'alpha' for transparency

    # Set axis labels
    ax.set_xlabel('Mixture Ratio (mr)')
    ax.set_ylabel('Pressure (Pa)')
    ax.set_zlabel('Adiabatic Flame Temperature (Tad) [K]')

    # Add a legend manually, since `plot_surface()` doesn't support labels directly
    handles = [plt.Line2D([0], [0], color=plt.cm.viridis(i / len(Ta)), lw=4) for i in range(len(Ta))]
    ax.legend(handles, Ta.keys(), loc='upper left')

    # Show the plot
    plt.show()
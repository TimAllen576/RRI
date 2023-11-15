import numpy as np
import matplotlib.pyplot as plt
import pandas as pd


#import matplotlib as mpl
#mpl.rcParams['figure.dpi'] = 600

def data_unpacker_hp(filename):
    """Unpacks the columns into a pandas dataframe"""
    names = ["x", "y", "z", "field", "SD", "n"]
    initial_df = pd.read_csv(filename, usecols=[0, 1, 2, 3], names=names)
    # initial_df.dropna(inplace=True)
    slices = len(pd.unique(initial_df.loc[:, "z"]))
    relevant_data = initial_df.drop(columns= "z")
    x_samples = int(len(relevant_data.loc[:, "y"]) / len(pd.unique(relevant_data.loc[:, "y"])) / slices)
    y_samples = len(pd.unique(relevant_data.loc[:, "y"]))
    x_step = abs(relevant_data.loc[:, "x"][1]- relevant_data.loc[:, "x"][0])
    y_step = abs(relevant_data.loc[:, "y"][x_samples]- relevant_data.loc[:, "y"][0])
    len_z = x_samples*y_samples
    new_shape = (x_samples, y_samples)
    fields = relevant_data.loc[:, "field"]
    split_data = []
    for _slice in range(slices):
        try:
            reformatted_data = np.reshape(fields.iloc[_slice*len_z:_slice*len_z+len_z], new_shape)
            split_data.append(reformatted_data)
        except TypeError:
            print(f"Impossible shape: {new_shape}")
            return None
    return split_data, x_step, y_step


def heatmap(split_data, x_step, y_step, filename):
    """Creates a heatmap of the magnetic field strength (z-direction)"""
    fig, axs = plt.subplots(ncols=len(split_data), sharex=True, sharey=True)
    for slice_no, data in enumerate(split_data):
        im = axs[slice_no].imshow(data)
        cbar = axs[slice_no].figure.colorbar(im)
        cbar.ax.set_ylabel("Field (T)", rotation=90, va="top")
        axs[slice_no].set_xlabel(f"x ({x_step}mm)")
        axs[slice_no].set_ylabel(f"y ({y_step}mm)")
    plt.savefig(filename)
    plt.show()


def data_unpacker_3d(filename):
    """Unpacks the data to go to a 3d plot_surface"""
    names = ["x", "y", "z", "field", "SD", "n"]
    initial_df = pd.read_csv(filename, usecols=[0, 1, 2, 3], names=names)
    # initial_df.dropna(inplace=True)
    slices = len(pd.unique(initial_df.loc[:, "z"]))
    relevant_data = initial_df.drop(columns= "z")
    len_z = int(len(relevant_data.loc[:, "x"]) / slices)
    split_data = []
    x_samples = int(len(relevant_data.loc[:, "y"]) / len(pd.unique(relevant_data.loc[:, "y"])) / slices)
    y_samples = len(pd.unique(relevant_data.loc[:, "y"]))
    new_shape = (x_samples, y_samples)
    for _slice in range(slices):
        slice_data = relevant_data.iloc[:, _slice*len_z:_slice*len_z+len_z]
        print(len_z)
        reformatted_data = np.reshape(slice_data.loc[:, "field"], new_shape)
        split_data.append([slice_data, reformatted_data])
    return split_data
    
def plot_3d(split_data, filename):
    """Plots the data as a 3d surface with colourbar"""
    fig, axs = plt.subplots(ncols=len(split_data), sharex=True, sharey=True, subplot_kw={"projection": "3d"})
    for slice_no, data in enumerate(split_data):
        surf = axs[slice_no].plot_surface(data[0].loc[:,"x"], data[0].loc[:,"y"], data[1])
    fig.colorbar(surf)
    plt.savefig(f"{filename}3d.png")
    plt.show()

def main():
    """Runs the whole boi"""
    filename = "test"
    #split_data, x_step, y_step = data_unpacker(filename)
    #heatmap(split_data, x_step, y_step, filename)
    split_data = data_unpacker_3d(filename)
    plot_3d(split_data, filename)

if __name__ == "__main__":
    main()

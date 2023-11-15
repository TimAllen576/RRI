import numpy as np
import matplotlib.pyplot as plt
import pandas as pd


def data_unpacker(filename):
    """Unpacks the columns into a pandas dataframe"""
    initial_df = pd.read_csv(filename, usecols=[0,1,2,3])
    initial_df.dropna(inplace=True)
    is_slice = len(pd.unique(initial_df.iloc[:, 2])) > 1 #Checks if all values are the same
    if is_sclice:
        relevant_data = initial_df.drop(axis=1, index=2)
        return relevant_data


def heatmap(data, filename):
    """Creates a heatmap of the magnetic field strength (z-direction)"""
    x, y, field = data.iloc[:, 0], data.iloc[:, 1], data.iloc[:, 2]
    x_samples = len(y) / len(pd.unique(y))
    y_samples = len(pd.unique(y))
    reformatted_data = np.reshape(field, (x_samples, y_samples))
    x_step = abs(x[1]- x[0])
    y_step = abs(y[1]- y[0])
    fig, ax = plt.subplots()
    im = ax.imshow(reformatted_data)
    cbar = ax.figure.colorbar(im)
    cbar.ax.set_ylabel("Field (T)", rotation=90, va="top")
    ax.set_xlabel(f"x ({x_step}mm)")
    ax.set_ylabel(f"y ({y_step}mm)")
    plt.savefig("filename")
    plt.show()


def main():
    """Runs the whole boi"""
    filename = "PM1"
    data = data_unpacker(filename)
    heatmap(data, filename)


if __name__ == "__main__":
    main()


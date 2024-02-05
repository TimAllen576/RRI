"""Makes v and current graphs of the power supply logs."""

from glob import glob
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt


def main():
    """Makes v and current graphs of the power supply logs."""
    for filename in glob("*.csv"):
        df = pd.read_csv(filename, header=6, usecols=[0, 1],
                         names=["voltage", "current"])
        df["Time"] = np.arange(0, len(df)) * 0.2
        df["Power"] = df["voltage"] * df["current"]
        plt.plot(df["Time"], df["voltage"])
        plt.plot(df["Time"], df["current"])
        plt.plot(df["Time"], df["Power"])
        plt.legend(["voltage", "current", "Power"])
        plt.title(filename)
        plt.xlabel("Time (s)")
        plt.ylabel("Voltage (V) , Current (A), Power (W)")
        plt.savefig(filename[:-4] + ".png")
        plt.clf()


if __name__ == "__main__":
    main()

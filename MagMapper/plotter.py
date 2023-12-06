"""Program to unpack, plot and compare magnets mapped using
the MagMapper"""

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import glob
from icecream import ic


U_0 = 4 * np.pi * 10 ** -7
HALL_INTERCEPT = -0.010254
HALL_SLOPE = 1.14189
APPROX_CENTRE = (33.5, -97.5)
INTERPOLATION_GRID = 1000

plt.rcParams.update({"figure.figsize": (10, 7), "figure.dpi": 200})


class MagMapperData:
    """Parent class to handle MagMapper data"""

    def rectify_field_direction(self):
        """Flips the sign of field data if necessary"""
        field_sign = np.sign(self.dataframe["field"][np.argmax(
            np.abs(self.dataframe["field"]))])
        self.dataframe["field"] = self.dataframe["field"] * field_sign

    def standard_deviation_mean(self):
        """Calculates and returns the maximum standard deviation
        of the mean"""
        return np.max(self.dataframe["std_field"] /
                      np.sqrt(self.dataframe["n"]))

    def save_plots(self):
        """Saves the open plots"""
        plt.savefig(f"Plots/{self.filename}.png")


class OldXYZRectangularData(MagMapperData):
    """Class to handle MagMapper data in the old rectangular format,
    changes in x then y then z"""
    # TODO add different order xyz

    def __init__(self, filename: str, dataframe: pd.DataFrame):
        """Names the columns, ensures field data is accessible
        and flips if necessary"""
        self.filename = filename
        self.dataframe = dataframe
        names = ["x", "y", "z", "volts", "std_volts", "n"]
        self.dataframe.columns = names
        self.dataframe["field"] = (self.dataframe["volts"]
                                   * HALL_SLOPE + HALL_INTERCEPT)
        self.dataframe["std_field"] = (self.dataframe["std_volts"]
                                       * HALL_SLOPE)
        self.rectify_field_direction()
        self.z_values = pd.unique(self.dataframe["z"])
        self.split_data = []  # Potentially separate for performance
        for z_slice_num, z_value in enumerate(self.z_values):
            slice_data = self.dataframe.loc[
                self.dataframe["z"] == z_value, ["x", "y", "field"]]
            slice_data.rename(
                columns={"field": f"field at z={z_value}mm"})
            self.split_data.append(slice_data)

    # noinspection PyTypeChecker
    def plot_heatmaps(self):
        """Plots the data as a heatmap"""
        # TODO output z val somewhere, pull out error checks?
        x_steps = np.diff(pd.unique(self.dataframe["x"]))
        y_steps = np.diff(pd.unique(self.dataframe["y"]))
        if not (np.all(x_steps == x_steps[0]) or
                np.all(y_steps == y_steps[0])):
            raise ValueError("x or y step sizes are not equal.")
        num_rows, num_cols = make_rectangle(len(self.z_values))
        fig, axs = plt.subplots(ncols=num_cols, nrows=num_rows,
                                sharex=True, sharey=True)
        axs = np.atleast_2d(axs)
        for ax_num, current_ax in enumerate(axs.flatten()):
            if ax_num >= len(self.z_values):
                current_ax.axis("off")
            else:
                slice_data = self.split_data[ax_num]
                # TODO Improve check for rectangular shaped data,
                #  duplicates and sample count (x, y dir?), check diff too
                y_samples = len(pd.unique(slice_data["y"]))
                x_samples = len(pd.unique(slice_data["x"]))
                if x_samples * y_samples != len(slice_data["y"]):
                    # TODO add nans for missing vals?
                    raise ValueError(f"Not all {y_samples} y samples have "
                                     f"{x_samples} x samples for "
                                     f"{len(slice_data['y'])} data points.")
                reshaped_data = np.reshape(
                    slice_data["field"], (x_samples, y_samples))
                # TODO change scales so labels unnecessary
                im = current_ax.imshow(reshaped_data)
                # TODO check formatting of colour-bars
                cbar = current_ax.figure.colorbar(im)
                current_ax.set_xlabel(f"x ({x_steps[0]}mm)")
                current_ax.set_ylabel(f"y ({y_steps[0]}mm)")
                cbar.ax.set_ylabel("Field (T)", rotation=90, va="top")
        plt.show(block=False)

    # noinspection PyTypeChecker
    def plot_3d(self):
        """Plots the data as a 3d surface with colour-bar"""
        x_steps = np.diff(pd.unique(self.dataframe["x"]))
        y_steps = np.diff(pd.unique(self.dataframe["y"]))
        if not (np.all(x_steps == x_steps[0]) or
                np.all(y_steps == y_steps[0])):
            raise ValueError("x or y step sizes are not equal.")
        num_rows, num_cols = make_rectangle(len(self.z_values))
        fig, axs = plt.subplots(ncols=num_cols, nrows=num_rows,
                                sharex=True, sharey=True,
                                subplot_kw={"projection": "3d"})
        axs = np.atleast_2d(axs)
        for ax_num, current_ax in enumerate(axs.flatten()):
            if ax_num >= len(self.z_values):
                current_ax.axis("off")
            else:
                slice_data = self.split_data[ax_num]
                y_samples = len(pd.unique(slice_data["y"]))
                x_samples = len(pd.unique(slice_data["x"]))
                if x_samples * y_samples != len(slice_data["y"]):
                    raise ValueError(f"Not all {y_samples} y samples"
                                     f" have {x_samples} x samples for"
                                     f" {len(slice_data['y'])} data"
                                     f" points.")
                reshaped_field = np.reshape(
                    slice_data["field"], (x_samples, y_samples))
                reshaped_x = np.reshape(
                    slice_data["x"], reshaped_field.shape)
                reshaped_y = np.reshape(
                    slice_data["y"], reshaped_field.shape)
                surf = current_ax.plot_surface(
                    reshaped_x, reshaped_y, reshaped_field,
                    cmap='plasma')
                current_ax.set_xlabel(f"x (mm)")
                current_ax.set_ylabel(f"y (mm)")
                current_ax.set_zlabel("Field (T)")
                cbar = current_ax.figure.colorbar(surf, ax=current_ax)
                cbar.ax.set_ylabel("Field (T)", rotation=90, va="top")
        plt.show(block=False)

    def plot_radial_slice(self):
        """Compatability with new data format"""
        # TODO add?
        print(f"{self.filename} contains data taken in a rectangular "
              f"format, which is not implemented for radial slices.")


class NewRotationalData(MagMapperData):
    """Class to handle MagMapper data in the new rotational format,
    changes in theta then x then z"""

    def __init__(self, filename, dataframe):
        """Names the columns, flips field if necessary,
        makes theta radians, centres the data and calculates r"""
        self.filename = filename
        self.dataframe = dataframe
        names = ["x", "y", "z", "theta_deg", "volts", "std_volts",
                 "field", "std_field", "n"]
        self.dataframe.columns = names
        self.rectify_field_direction()
        self.z_values = pd.unique(self.dataframe["z"])
        self.dataframe["theta"] = np.deg2rad(self.dataframe[
                                                 "theta_deg"])
        self.z_values = pd.unique(self.dataframe["z"])
        self.centre_xy()
        # Could just be set to x
        self.dataframe["r"] = np.sqrt(
            self.dataframe["x"] ** 2 + self.dataframe["y"] ** 2)
        # duplicates pulled first since pandas lacks a stable sort when
        # sorting by multiple columns
        duplicated_mask = self.dataframe.duplicated(
            subset=["r", "theta"], keep=False)
        self.duplicated_measures = self.dataframe.loc[duplicated_mask]
        # TODO use duplicated_measures to evaluate accuracy
        self.dataframe.drop_duplicates(subset=["r", "theta"],
                                       inplace=True)
        self.dataframe.sort_values(
            ["z", "x", "theta"], axis="columns", inplace=True,
            ignore_index=True)
        self.split_data = []
        for z_slice_num, z_value in enumerate(self.z_values):
            slice_data = self.dataframe.loc[
                self.dataframe["z"] == z_value, ["r", "theta", "field"]]
            slice_data.rename(
                columns={"field": f"field at z={z_value}mm"})  # Arguable -----
            self.split_data.append(slice_data)

    def centre_xy(self):
        """With available data, centres the values around lowest
        field change per theta"""
        # TODO compare to forming 200 sided shape with duplicate
        #  measures at const theta
        field_change_list = []
        # y offset much more difficult to determine, taken as 0 for now
        self.dataframe["y"] = 0
        min_allowed_value = np.mean(self.dataframe["field"])
        for x_radius in pd.unique(self.dataframe["x"]):
            radial_data = self.dataframe.loc[
                self.dataframe["x"] == x_radius, ["field", "z"]]
            # Assumes negative z is closer to magnet
            slice1_radial_data = radial_data.loc[
                radial_data["z"] == np.min(self.z_values), "field"]
            # Bias to high field to avoid far outer edge
            if np.min(slice1_radial_data) > min_allowed_value:
                field_change = (np.max(slice1_radial_data) -
                                np.min(slice1_radial_data))
                field_change_list.append([field_change, x_radius])
        field_change_arr = np.array(field_change_list)
        min_sum_idx = np.argmin(field_change_arr[:, 0])
        min_sum_x = field_change_arr[min_sum_idx, 1]
        self.dataframe["x"] -= min_sum_x
        return None

    # noinspection PyTypeChecker
    def plot_heatmaps(self):
        """Plots the data as a heatmap"""
        # TODO is this necessary?
        # r_steps = np.diff(pd.unique(self.dataframe["r"]))
        # theta_steps = np.diff(pd.unique(self.dataframe["theta"]))
        # if not (np.all(r_steps == r_steps[0]) or
        #         np.all(theta_steps == theta_steps[0])):
        #     raise ValueError("x or y step sizes are not equal.")
        num_rows, num_cols = make_rectangle(len(self.z_values))
        fig, axs = plt.subplots(ncols=num_cols, nrows=num_rows,
                                sharex=True, sharey=True,
                                subplot_kw={'polar': 'True'})
        axs = np.atleast_2d(axs)
        for ax_num, current_ax in enumerate(axs.flatten()):
            if ax_num >= len(self.z_values):
                current_ax.axis("off")
            else:
                slice_data = self.split_data[ax_num]
                slice_data.drop_duplicates(subset=["r", "theta"],
                                           inplace=True)  # TODO pull out/sort
                r_vals = pd.unique(slice_data["r"])
                theta_vals = pd.unique(slice_data["theta"])
                r_samples = len(r_vals)
                theta_samples = len(theta_vals)
                if r_samples * theta_samples != len(slice_data.index):
                    raise ValueError(f"Not all {r_samples} radius "
                                     f"samples have {theta_samples} "
                                     f"theta samples for "
                                     f"{len(slice_data.index)} "
                                     f"data points.")
                # TODO check theta direction, location
                r, th = np.meshgrid(r_vals, theta_vals)
                # Packing of theta and r are switched vs plt expected
                field = np.reshape(slice_data["field"], r.T.shape)
                im = current_ax.pcolormesh(th, r, field.T)
                # TODO check formatting many plots
                current_ax.set_rticks([0, max(r_vals)])
                # Magic nums put text next to outer r tick, could be
                # done like ThetaFormatter but not worth the time
                current_ax.text(0.36, max(r_vals) + 4.5, "(mm)",
                                va='center', ha='center',
                                rotation='horizontal',
                                rotation_mode='anchor')
                current_ax.grid(False)
                cbar = current_ax.figure.colorbar(im, pad=0.1)
                cbar.ax.set_ylabel("Field (T)", rotation=90, va="top")
        plt.show(block=False)

    def plot_radial_slice(self):
        """Plots slices of constant radii (currently only 1 z_val)"""
        close_slice = self.dataframe
        close_slice.drop_duplicates(subset=["r", "theta"],
                                    inplace=True)
        radii = pd.unique(close_slice["r"])[::4]  # Variable-------------------
        fig, axs = plt.subplots(len(radii), sharex=True)
        fig.subplots_adjust(hspace=0)
        axs = np.atleast_1d(axs)
        for radius_idx, radius in enumerate(radii):
            radial_data = close_slice.loc[
                close_slice["r"] == radius,
                ["theta", "field"]]
            mean_centred_field = (radial_data["field"] - np.mean(
                radial_data["field"]))*1000
            axs[radius_idx].plot(radial_data["theta"],
                                 mean_centred_field, "o-", markersize=2)
            axs[radius_idx].set_ylabel(f"r={radius:.2f}mm", rotation=0,
                                       labelpad=35)
            axs[radius_idx].yaxis.set_label_position("right")
            # axs[radius_idx].tick_params(axis="y", labelsize=4)
        fig.supxlabel("Theta (rad)")
        fig.supylabel("$B_z - B_{z, mean}$ (mT)")
        plt.show(block=True)


# region slices
class Slice(MagMapperData):
    """Parent class for x and y slices"""

    def __init__(self, filename, dataframe):
        """Names the columns, flips field if necessary"""
        self.filename = filename
        self.dataframe = dataframe
        names = ["x", "y", "z", "theta_deg", "volts", "std_volts",
                 "field", "std_field", "n"]
        self.dataframe.columns = names
        self.rectify_field_direction()

    def plot_heatmap(self):
        """Compatability with other data formats"""
        print(f"{self.filename} contains 2d slice data which cannot be"
              f"plotted as heatmap")

    def plot_3d(self):
        """Compatability with other data formats"""
        print(f"{self.filename} contains 2d slice data which cannot be"
              f"plotted as a 3d surface")

    def plot_radial_slice(self):
        """Compatability with other data formats"""
        print(f"{self.filename} contains data taken as a slice, which "
              f"is not compatible with radial slices.")


class XSlice(Slice):
    """Class for handling data from a slice in the x-direction"""

    def plot(self):
        """Plots the slice on 2d graph showing change in field"""
        plt.plot(self.dataframe["y"], self.dataframe["field"], "o")
        plt.xlabel("y (mm)")
        plt.ylabel("Field (T)")
        plt.show()


class YSlice(Slice):
    """Class for handling data from a slice in the y-direction"""

    def plot(self):
        """Plots the slice on 2d graph showing change in field"""
        plt.plot(self.dataframe["x"], self.dataframe["field"], "o")
        plt.xlabel("x (mm)")
        plt.ylabel("Field (T)")
        plt.show()
# endregion


def unpack_magmapper_data(filename):
    """Uses the appropriate classes to unpack the MagMapper data"""
    # TODO: recalibrate hall sensor?, include z val in plots(only rel)
    #  check sd and n too, esp old files,
    #  return non-centered data at end?,
    #  checks to make sure data is good(as expected)
    dataframe = pd.read_csv(filename, header=None)
    dataframe.dropna(axis=0, how="all", inplace=True)
    dataframe.dropna(axis=1, how="all", inplace=True)
    num_names = len(dataframe.columns)
    if num_names != 6 and num_names != 9:
        raise ValueError(f"Invalid data format. There are {num_names}"
                         f"columns, expected 6 or 9.")
    elif num_names == 6:
        return OldXYZRectangularData(filename, dataframe)
    data = NewRotationalData(filename, dataframe)
    if len(pd.unique(data.dataframe["theta"])) == 1:
        if len(pd.unique(data.dataframe["x"])) == 1:
            data = YSlice(filename, dataframe)
        elif len(pd.unique(data.dataframe["y"])) == 1:
            data = XSlice(filename, dataframe)
    return data

# region rectangle
def make_rectangle(length):
    """Finds dimensions of a minimal rectangle
    (closest to square, with no empty rows/cols)
    from the given length"""
    rows, cols = 1, 1
    while rows * cols < length:
        if cols > rows:
            rows += 1
        else:
            cols += 1
    return rows, cols
# endregion


def main():
    """Runs the whole boi"""
    # Todo plot slices, const theta (opt for centering), 3d
    #  check accuracy (sd and n, duplicates)
    filename1 = "Tims_measurements/C350_5/C350_5_N_rot(day)"
    data1 = unpack_magmapper_data(filename1)
    # data1.plot_heatmaps()
    # data1.plot_3d()
    data1.plot_radial_slice()


if __name__ == "__main__":
    main()

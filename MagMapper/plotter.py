"""Program to unpack, plot and compare magnets mapped using
the MagMapper"""

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import uncertainties as unc
# noinspection PyUnresolvedReferences
import glob
# noinspection PyUnresolvedReferences
from icecream import ic

U_0 = 4 * np.pi * 10 ** -7
HALL_INTERCEPT = -0.010254
HALL_SLOPE = 1.14189
MAX_GRAPHS = 8

plt.rcParams.update({"polaraxes.grid": False})


class MagMapperData:
    """Parent class to handle MagMapper data"""

    def rectify_field_direction(self):
        """Flips the sign of field data if necessary"""
        field_sign = np.sign(self.dataframe["field"][np.argmax(
            np.abs(self.dataframe["field"]))])
        self.dataframe["field"] = self.dataframe["field"] * field_sign

    def print_accuracy(self):
        """Prints the accuracy of the data. Mean, std, min/max"""
        print(f"{self.filename}\n"
              f"Duplicates:\n{self.duplicated_measures}\n"
              f"Mean std: {np.mean(self.dataframe["std_field"]):.3e} T\n"
              f"Minimum std: {np.min(self.dataframe["std_field"]):.3e} T\n"
              f"Maximum std: {np.max(self.dataframe["std_field"]):.3e} T\n"
              f"Max standard error estimator: "
              f"{np.max(self.dataframe["std_field"] /
                        np.sqrt(self.dataframe["n"])):.3e} T\n")

    def print_characteristic(self):
        """Prints the characteristic value for the field data"""
        sum_amp_diffs = 0
        sum_amp_diffs_err = 0
        number_radii = 0
        for data_num, z_value_data in enumerate(self.split_data):
            radii = pd.unique(z_value_data["r"])
            for radius_idx, radius in enumerate(radii):
                radial_data = z_value_data.loc[
                    z_value_data["r"] == radius,
                    ["field", "std_err_est"]]
                sum_amp_diffs += (np.max(radial_data["field"]) -
                                  np.min(radial_data["field"]))
                sum_amp_diffs_err += radial_data["std_err_est"].iloc[
                    np.argmax(radial_data["field"] + radial_data[
                        "std_err_est"])]
                sum_amp_diffs_err += radial_data["std_err_est"].iloc[
                    np.argmin(radial_data["field"] + radial_data[
                        "std_err_est"])]
                number_radii += 1
            if "r" not in z_value_data.columns:
                raise ValueError(f"{self.filename} data must be split by"
                                 f" radius\n")
        inhomogeneity = unc.ufloat(sum_amp_diffs / number_radii,
                                   sum_amp_diffs_err / number_radii)
        inhomogeneity *= 1000
        print(f"Characteristic value {self.filename}: "
              f"{inhomogeneity:P} mT")


class OldXYZRectangularData(MagMapperData):
    """Class to handle MagMapper data in the old rectangular format,
    changes in x then y then z"""

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
                columns={"field": f"field at z={z_value}mm"})  # reevaluate
            self.split_data.append(slice_data)

    @staticmethod
    def plot_heatmaps() -> None:
        """Plots the data as a heatmap"""
        print("This method is kept as legacy code and should not be used"
              " as it does not sufficiently visualize differences. "
              "Use plot_3d instead.")
        # Last todos were error checks, formatting and possible change
        # to pcolormesh

        # x_steps = np.diff(pd.unique(self.dataframe["x"]))
        # y_steps = np.diff(pd.unique(self.dataframe["y"]))
        # if not (np.all(x_steps == x_steps[0]) or
        #         np.all(y_steps == y_steps[0])):
        #     raise ValueError("x or y step sizes are not equal.")
        # num_rows, num_cols = make_rectangle(len(self.z_values))
        # fig, axs = plt.subplots(ncols=num_cols, nrows=num_rows,
        #                         sharex=True, sharey=True)
        # axs = np.atleast_2d(axs)
        # for ax_num, current_ax in enumerate(axs.flatten()):
        #     current_ax: plt.axes
        #     if ax_num >= len(self.z_values):
        #         current_ax.axis("off")
        #     else:
        #         slice_data = self.split_data[ax_num]
        #         y_samples = len(pd.unique(slice_data["y"]))
        #         x_samples = len(pd.unique(slice_data["x"]))
        #         if x_samples * y_samples != len(slice_data["y"]):
        #             raise ValueError(f"Not all {y_samples} y samples have "
        #                              f"{x_samples} x samples for "
        #                              f"{len(slice_data['y'])} data points.")
        #         reshaped_data = np.reshape(
        #             slice_data["field"], (x_samples, y_samples))
        #         extent = [np.min(slice_data["x"]), np.max(slice_data["x"]),
        #                   np.min(slice_data["y"]), np.max(slice_data["y"])]
        #         im = current_ax.imshow(reshaped_data, extent=extent)
        #         current_ax.set(xlabel="x (mm)", ylabel="y (mm)",
        #                        title=f"z={self.z_values[ax_num]}mm")
        #         cbar = current_ax.figure.colorbar(im)
        #         cbar.ax.set_ylabel("Field (T)", rotation=90, va="top")

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
        ax_arr = np.atleast_2d(axs)
        for ax_num, current_ax in enumerate(ax_arr.flatten()):
            current_ax: plt.axes
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
                current_ax.set_title(f"z={self.z_values[ax_num]}mm")
                cbar = current_ax.figure.colorbar(surf, ax=current_ax)
                cbar.ax.set_ylabel("Field (T)", rotation=90, va="top")

    def plot_radial_slice(self):
        """Compatability with new data format"""
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
        self.dataframe["theta"] = np.deg2rad(self.dataframe["theta_deg"])
        self.dataframe["std_err_est"] = (self.dataframe["std_field"] /
                                         np.sqrt(self.dataframe["n"]))
        self.centre_xy()
        # Could just be set to x
        self.dataframe["r"] = np.sqrt(
            self.dataframe["x"] ** 2 + self.dataframe["y"] ** 2)
        # duplicates pulled first since pandas lacks a stable sort when
        # sorting by multiple columns
        duplicated_mask = self.dataframe.duplicated(
            subset=["r", "theta", "z"], keep=False)
        self.duplicated_measures = self.dataframe.loc[duplicated_mask]
        self.dataframe.drop_duplicates(subset=["r", "theta", "z"],
                                       inplace=True)  # ----------sep
        self.dataframe.sort_values(
            ["z", "x", "theta"], axis=0, inplace=True,
            ignore_index=True)
        self.split_data = []
        for z_value in self.z_values:
            slice_data = self.dataframe.loc[
                self.dataframe["z"] == z_value,
                ["r", "theta", "field", "std_err_est"]]
            self.split_data.append(slice_data)

    def centre_xy(self):
        """With available data, centres the values around lowest
        field change per theta"""
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

    @staticmethod
    def plot_heatmaps() -> None:
        """Plots the data as a heatmap"""
        print("This method is kept as legacy code and should not be used"
              " as it does not sufficiently visualize differences. "
              "Use plot_3d instead.")
        # Last todos were error checks and formatting

        # r_steps = np.diff(pd.unique(self.dataframe["r"]))
        # theta_steps = np.diff(pd.unique(self.dataframe["theta"]))
        # if not (np.all(r_steps == r_steps[0]) or
        #         np.all(theta_steps == theta_steps[0])):
        #     raise ValueError("x or y step sizes are not equal.")
        # num_rows, num_cols = make_rectangle(len(self.z_values))
        # fig, axs = plt.subplots(ncols=num_cols, nrows=num_rows,
        #                         sharex=True, sharey=True,
        #                         subplot_kw={"polar": "True"},
        #                         layout="compressed")
        # axs = np.atleast_2d(axs)
        # for ax_num, current_ax in enumerate(axs.flatten()):
        #     current_ax: plt.axes
        #     if ax_num >= len(self.z_values):
        #         current_ax.axis("off")
        #     else:
        #         slice_data = self.split_data[ax_num]
        #         r_values = pd.unique(slice_data["r"])
        #         theta_values = pd.unique(slice_data["theta"])
        #         r_samples = len(r_values)
        #         theta_samples = len(theta_values)
        #         if r_samples * theta_samples != len(slice_data.index):
        #             raise ValueError(f"Not all {r_samples} radius "
        #                              f"samples have {theta_samples} "
        #                              f"theta samples for "
        #                              f"{len(slice_data.index)} "
        #                              f"data points.")
        #         r, th = np.meshgrid(r_values, theta_values)
        #         # Packing of theta and r are switched vs plt expected
        #         field = np.reshape(slice_data["field"], r.T.shape)
        #         im = current_ax.pcolormesh(th, r, field.T)
        #         current_ax.set(theta_direction=-1, rticks=[0, max(r_values)],
        #                        title=f"z={self.z_values[ax_num]}mm",
        #                        theta_offset=np.pi/2)
        #         # Magic nums put text "mm" next to outer r tick, could be
        #         # done like ThetaFormatter but not worth the time
        #         current_ax.text(0.36, max(r_values) + 4.5, "(mm)",
        #                         va='center', ha='center',
        #                         rotation='horizontal',
        #                         rotation_mode='anchor')
        #         cbar = current_ax.figure.colorbar(im, pad=0.1)
        #         cbar.ax.set_ylabel("Field (T)", rotation=90, va="top")

    def plot_radial_slice(self):
        """Plots slices of constant radii"""
        for data_num, z_value_data in enumerate(self.split_data):
            step_size = int(
                np.ceil(len(pd.unique(z_value_data["r"])) / MAX_GRAPHS))
            radii = pd.unique(z_value_data["r"])[::-step_size]
            fig, axs = plt.subplots(len(radii), sharex=True)
            fig.subplots_adjust(hspace=0)
            ax_arr = np.atleast_1d(axs)
            for radius_idx, radius in enumerate(radii):
                current_axs = ax_arr[radius_idx]
                current_axs: plt.axes
                radial_data = z_value_data.loc[
                    z_value_data["r"] == radius,
                    ["theta", "field"]]
                mean_centred_field = (radial_data["field"] - np.mean(
                    radial_data["field"])) * 1000
                current_axs.plot(radial_data["theta"],
                                 mean_centred_field, "o-", markersize=2)
                current_axs.set_ylabel(f"r={radius:.2f}mm", rotation=0,
                                       labelpad=30)
                current_axs.yaxis.set_label_position("right")
            fig.supxlabel("Theta (rad)")
            fig.supylabel("$B_z - B_{z, mean}$ (mT)")
            fig.suptitle(f"Radial plots for z={self.z_values[data_num]}mm")

    def plot_theta_slice(self):
        """Plots slices of constant theta"""
        for data_num, z_value_data in enumerate(self.split_data):
            step_size = int(
                np.ceil(len(pd.unique(z_value_data["theta"])) / MAX_GRAPHS))
            thetas = pd.unique(z_value_data["theta"])[::step_size]
            fig, axs = plt.subplots(len(thetas), sharex=True)
            fig.subplots_adjust(hspace=0)
            ax_arr = np.atleast_1d(axs)
            for theta_idx, theta in enumerate(thetas):
                current_axs = ax_arr[theta_idx]
                current_axs: plt.axes
                theta_data = z_value_data.loc[
                    z_value_data["theta"] == theta,
                    ["r", "field"]]
                mean_centred_field = (theta_data["field"] - np.mean(
                    theta_data["field"])) * 1000
                current_axs.plot(theta_data["r"],
                                 mean_centred_field, "o-", markersize=2)
                current_axs.set_ylabel(f"theta={theta:.2f}rad",
                                       rotation=0,
                                       labelpad=35)
                current_axs.yaxis.set_label_position("right")
            fig.supxlabel("r (mm)")
            fig.supylabel("$B_z - B_{z, mean}$ (mT)")
            fig.suptitle(f"Theta plots for z={self.z_values[data_num]}mm")

    def plot_3d(self):
        """Plots the data as a 3d surface with colour-bar"""
        num_rows, num_cols = make_rectangle(len(self.z_values))
        fig, axs = plt.subplots(ncols=num_cols, nrows=num_rows,
                                sharex=True, sharey=True,
                                subplot_kw={"projection": "3d"})
        axs = np.atleast_2d(axs)
        for ax_num, current_ax in enumerate(axs.flatten()):
            current_ax: plt.axes
            if ax_num >= len(self.z_values):
                current_ax.axis("off")
            else:
                slice_data = self.split_data[ax_num]
                r_values = pd.unique(slice_data["r"])
                theta_values = pd.unique(slice_data["theta"])
                r_samples = len(r_values)
                theta_samples = len(theta_values)
                # if r_samples * theta_samples != len(slice_data.index):
                #     raise ValueError(f"Not all {r_samples} radius "
                #                      f"samples have {theta_samples} "
                #                      f"theta samples for "
                #                      f"{len(slice_data.index)} "
                #                      f"data points.")
                r, th = np.meshgrid(r_values,
                                    np.append(theta_values, 2 * np.pi))
                x, y = r * np.cos(th), r * np.sin(th)
                # Packing of theta and r are switched vs plt expected
                field = np.reshape(slice_data["field"], r.T.shape)
                surf = current_ax.plot_surface(
                    x, y, field.T, cmap='plasma')
                current_ax.set_xlabel(f"x (mm)")
                current_ax.set_ylabel(f"y (mm)")
                current_ax.set_zlabel("Field (T)")
                current_ax.set_title(f"z={self.z_values[ax_num]}mm")
                cbar = current_ax.figure.colorbar(surf, ax=current_ax,
                                                  pad=0.3)
                cbar.ax.set_ylabel("Field (T)", rotation=90, va="top")


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

    def plot_heatmaps(self):
        """Compatability with other data formats"""
        print(f"{self.filename} contains 2d slice data which cannot be"
              f" plotted as a heatmap")

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


class YSlice(Slice):
    """Class for handling data from a slice in the y-direction"""

    def plot(self):
        """Plots the slice on 2d graph showing change in field"""
        plt.plot(self.dataframe["x"], self.dataframe["field"], "o")
        plt.xlabel("x (mm)")
        plt.ylabel("Field (T)")


# endregion


def unpack_magmapper_data(path):
    """Uses the appropriate classes to unpack the MagMapper data"""
    dataframe = pd.read_csv(path, header=None)
    filename = path.split("\\")[-1]
    dataframe.dropna(axis=0, how="all", inplace=True)
    dataframe.dropna(axis=1, how="all", inplace=True)
    num_names = len(dataframe.columns)
    if num_names != 6 and num_names != 9:
        raise ValueError(f"Invalid data format. There are {num_names}"
                         f"columns, expected 6 or 9.")
    elif num_names == 6:
        return OldXYZRectangularData(filename, dataframe)
    if len(pd.unique(dataframe[3])) == 1:  # Theta
        if len(pd.unique(dataframe[0])) == 1:  # X
            data = YSlice(filename, dataframe)
        elif len(pd.unique(dataframe[1])) == 1:  # Y
            data = XSlice(filename, dataframe)
        else:
            raise ValueError("Unknown data format.")
    else:
        data = NewRotationalData(filename, dataframe)
    return data


# region make rectangle
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
    # TODO fix 3d plot, math, skip dupes for 3d
    #  check full dupe measurements, check centering acc, 300micron rad mov
    #  pull out and verify/refine error checks, (tests)
    #  check formatting of colour-bars,
    #  Tests?: check attributes of classes
    #  check bad data, check "known" data

    # Potential additions:
    # add different order classes,
    # add nans for missing values (usually not needed),
    # add plot_radial slice to rectangular data (hard/unnecessary),
    # duplicate handling rectangular data (can just toss currently),
    # recalibrate hall sensor (may not need),
    # many sided shape for centering (requires v high resolution),
    # graceful accuracy description (need to check for duplicates and
    #                                involve multiple files)
    # return non-centered data at end (coordinates move) x

    for path in glob.glob("**/*/C350_5*"):
        data = unpack_magmapper_data(path)
        # data.plot_3d()
        # data.plot_radial_slice()
        # data.print_accuracy()
        # data.print_characteristic()
        if plt.gcf().get_axes():
            # plt.savefig(f"Plots/{data.filename}.pdf", format="pdf")
            plt.show()
            # plt.clf()


if __name__ == "__main__":
    main()

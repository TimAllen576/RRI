"""Program to unpack, plot and compare magnets mapped using
the MagMapper"""

import matplotlib as mpl
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from scipy.interpolate import CloughTocher2DInterpolator
from icecream import ic

U_0 = 4 * np.pi * 10 ** -7
HALL_INTERCEPT = -0.010254
HALL_SLOPE = 1.14189
APPROX_CENTRE = (33.5, -97.5)
INTERPOLATION_GRID = 1000


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


class OldRectangularFormatData(MagMapperData):
    """Class to handle MagMapper data in the old rectangular format,
    changes in x then y then z"""

    def __init__(self, filename, dataframe):
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


    def plot_heatmap(self):
        """Plots the data as a heatmap"""
        x_step = abs(self.dataframe["x"][0] - self.dataframe["x"][1])
        y_step = abs(pd.unique(self.dataframe["y"])[0] -
                     pd.unique(self.dataframe["y"])[1])
        fig, axs = plt.subplots(ncols=len(split_data),
                                sharex=True, sharey=True)
        for slice_no, data in enumerate(split_data):
            if len(split_data) != 1:
                im = axs[slice_no].imshow(data[1])
                cbar = axs[slice_no].figure.colorbar(im)
                axs[slice_no].set_xlabel(f"x ({x_step}mm)")
                axs[slice_no].set_ylabel(f"y ({y_step}mm)")
            else:
                im = axs.imshow(data[1])
                cbar = axs.figure.colorbar(im)
                axs.set_xlabel(f"x ({x_step}mm)")
                axs.set_ylabel(f"y ({y_step}mm)")
            cbar.ax.set_ylabel("Field (T)", rotation=90, va="top")
        plt.show(block=True)


class NewRotationalFormatData(MagMapperData):
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
        self.dataframe["theta"] = np.deg2rad(self.dataframe["theta_deg"])
        self.centre_xy()
        self.dataframe["r"] = np.sqrt(
            self.dataframe["x"] ** 2 + self.dataframe["y"] ** 2)

    def centre_xy(self):
        """Centres the x and y data"""
        # TODO: check centering (~0.0007 vs ~0.003)
        #  check taking max val vs lowest sum amps
        self.dataframe["x"] -= APPROX_CENTRE[0]
        self.dataframe["y"] = self.dataframe["y"] - APPROX_CENTRE[1]

    def plot(self):
        """Plots the magnetic field strength in the z-direction
        as a 3d surface with a colour-bar
        """


    def plot_heatmap(self):
        """Plots the data as a heatmap"""
        x_step = abs(self.dataframe["x"][0] - self.dataframe["x"][1])
        y_step = abs(pd.unique(self.dataframe["y"])[0] -
                     pd.unique(self.dataframe["y"])[1])
        fig, axs = plt.subplots(ncols=len(split_data),
                                sharex=True, sharey=True)
        for slice_no, data in enumerate(split_data):
            if len(split_data) != 1:
                im = axs[slice_no].imshow(data[1])
                cbar = axs[slice_no].figure.colorbar(im)
                axs[slice_no].set_xlabel(f"x ({x_step}mm)")
                axs[slice_no].set_ylabel(f"y ({y_step}mm)")
            else:
                im = axs.imshow(data[1])
                cbar = axs.figure.colorbar(im)
                axs.set_xlabel(f"x ({x_step}mm)")
                axs.set_ylabel(f"y ({y_step}mm)")
            cbar.ax.set_ylabel("Field (T)", rotation=90, va="top")
        plt.show(block=True)


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
        """Plots the data as a heatmap"""
        print(f"{self.filename} contains 2d slice data which cannot be"
              f"plotted as heatmap")


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


def unpack_magmapper_data(filename):
    """Uses the appropriate classes to unpack the MagMapper data"""
    # TODO: Improve multiple slice handling,
    #  recalibrate hall sensor?, include z val in plots(only rel)
    #  check sd and n too, esp old files,
    #  return non-centered data at end?,
    #  checks to make sure data is good
    dataframe = pd.read_csv(filename)
    num_names = len(dataframe.columns)
    if num_names != 6 and num_names != 9:
        raise ValueError("Invalid data format")
    elif num_names == 6:
        return OldRectangularFormatData(filename, dataframe)
    data = NewRotationalFormatData(filename, dataframe)
    if len(pd.unique(data.dataframe["x"])) == 1:
        data = YSlice(filename, dataframe)
    elif len(pd.unique(data.dataframe["y"])) == 1:
        data = XSlice(filename, dataframe)
    return data


def rad_unpack():
    # radius_sample = initial_df.where(initial_df["r"] == 10).dropna()
    # ic(radius_sample)
    # plt.plot(radius_sample["theta"], radius_sample["field"], "o")
    # plt.show()
    cart_df = cylindrical_to_cartesian(
        initial_df.loc[:, ["r", "theta", "field"]])
    interp_list = interp_2d(cart_df)
    frames = []
    for y_val in interp_list[1]:
        xy_slice = pd.DataFrame(
            {"x": interp_list[0], "y": [y_val] * len(interp_list[0])})
        frames.append(xy_slice)
    xy_df = pd.concat(frames, axis=0, ignore_index=True)
    field_series = pd.Series(np.array(interp_list[2]).flatten(),
                             name="field", dtype=np.float64)
    grid_cart_df = pd.concat([xy_df, field_series], axis=1)
    # -----------------------
    # ------------------------
    return [[grid_cart_df, interp_list[2]]]


def reshaper(data):
    """Reshapes the data into a 2d array"""
    split_data = []
    num_slices = len(pd.unique(data["z"]))
    z_samples = int(len(data["x"]) / num_slices)
    y_samples = len(pd.unique(data["y"]))
    x_samples = int(len(data["y"]) / y_samples / num_slices)
    new_shape = (x_samples, y_samples)
    for _slice in range(num_slices):
        offset = _slice * z_samples
        slice_data = data.iloc[
                     offset: offset + z_samples]
        reformatted_data = np.reshape(
            slice_data["field"], new_shape)
        split_data.append([slice_data, reformatted_data])
    return split_data


def interp_2d(irregular_data):
    """Interpolates radial data back to a 2d grid, remove?"""
    # TODO smart set values for interp grid?
    interp = CloughTocher2DInterpolator(
        list(zip(irregular_data["x"], irregular_data["y"])),
        irregular_data["field"])
    structured_data = pd.DataFrame()
    structured_data["x"] = np.linspace(
        min(irregular_data["x"]), max(irregular_data["x"]),
        num=INTERPOLATION_GRID)
    structured_data["y"] = structured_data["x"]
    x_grid, y_grid = np.meshgrid(
        structured_data["x"], structured_data["y"])
    interp_field = interp(x_grid, y_grid)
    return [structured_data["x"], structured_data["y"], interp_field]


def heatmap(split_data, filename=""):
    """Creates a heatmap of the magnetic field strength (z-direction)"""
    x_step = abs(pd.unique(split_data[0][0]["x"])[0] -
                 pd.unique(split_data[0][0]["x"])[1])
    y_step = abs(pd.unique(split_data[0][0]["y"])[0] -
                 pd.unique(split_data[0][0]["y"])[1])
    fig, axs = plt.subplots(ncols=len(split_data),
                            sharex=True, sharey=True)
    for slice_no, data in enumerate(split_data):
        if len(split_data) != 1:
            im = axs[slice_no].imshow(data[1])
            cbar = axs[slice_no].figure.colorbar(im)
            axs[slice_no].set_xlabel(f"x ({x_step}mm)")
            axs[slice_no].set_ylabel(f"y ({y_step}mm)")
        else:
            im = axs.imshow(data[1])
            cbar = axs.figure.colorbar(im)
            axs.set_xlabel(f"x ({x_step}mm)")
            axs.set_ylabel(f"y ({y_step}mm)")
        cbar.ax.set_ylabel("Field (T)", rotation=90, va="top")
    if filename:
        plt.savefig(f"Plots/{filename}.png")
    plt.show(block=True)


def plot_3d(split_data, filename=""):
    """Plots the data as a 3d surface with colour-bar"""
    fig, axs = plt.subplots(ncols=len(split_data),
                            sharex=True, sharey=True,
                            subplot_kw={"projection": "3d"})
    for slice_no, data in enumerate(split_data):
        x, y, z = (data[0]["x"], data[0]["y"], data[1])
        x2d = np.reshape(x, np.shape(z))
        y2d = np.reshape(y, np.shape(z))
        if len(split_data) != 1:
            axs[slice_no].plot_surface(x2d, y2d, z, cmap='plasma')
            axs[slice_no].set_xlabel("x (mm)")
            axs[slice_no].set_ylabel("y (mm)")
            axs[slice_no].set_zlabel("Field (T)")
            norm = mpl.colors.Normalize(vmin=0, vmax=np.max(z))
            sm = plt.cm.ScalarMappable(cmap='plasma', norm=norm)
            sm.set_array([])
            cbar = plt.colorbar(sm, ax=axs[slice_no])
        else:
            surf = axs.plot_surface(x2d, y2d, z, cmap='plasma')
            axs.set_xlabel("x (mm)")
            axs.set_ylabel("y (mm)")
            axs.set_zlabel("Field (T)")
            cbar = plt.colorbar(surf, ax=axs)
    # noinspection PyUnboundLocalVariable
    cbar.ax.set_ylabel("Field (T)", rotation=90, va="top")
    if filename:
        plt.savefig(f"Plots/{filename}_3d.png")
    plt.show(block=True)


def cartesian_to_cylindrical(xyz_dataframe):
    """Converts the coordinates from cartesian to cylindrical credit mtrw
    Input : xyz_dataframe (2d DataFrame with x, y, field columns)
    Returns : 2d array of data in cylindrical coordinates,
    columns r, theta, field"""
    # TODO: adjust array vs df handling throughout
    #  (everything should be df)
    if isinstance(xyz_dataframe, pd.DataFrame):
        xyz_data = xyz_dataframe.to_numpy()
    else:
        xyz_data = xyz_dataframe
    cylindrical_data = np.hstack((xyz_data, np.zeros(xyz_data.shape)))
    xy = xyz_data[:, 0] ** 2 + xyz_data[:, 1] ** 2
    cylindrical_data[:, 3] = np.sqrt(xy + xyz_data[:, 2] ** 2)
    cylindrical_data[:, 4] = np.arctan2(xyz_data[:, 1], xyz_data[:, 0])
    cylindrical_data[:, 5] = xyz_data[:, 2]
    return cylindrical_data[:, 3:6]


def cylindrical_to_cartesian(cylinder_data):
    """Converts back from cylindrical coords to xyz"""
    if isinstance(cylinder_data, pd.DataFrame):
        cylinder_data = cylinder_data.to_numpy()
    cartesian_data = np.zeros(cylinder_data.shape)
    cartesian_data[:, 0] = cylinder_data[:, 0] * np.cos(
        cylinder_data[:, 1])
    cartesian_data[:, 1] = cylinder_data[:, 0] * np.sin(
        cylinder_data[:, 1])
    cartesian_data[:, 2] = cylinder_data[:, 2]
    return pd.DataFrame(cartesian_data, columns=['x', 'y', 'field'])


def dft_helper(field_data, radii):
    """Helper function for unrolling data and taking the dft"""
    radial_data = cartesian_to_cylindrical(centre_helper(field_data))
    samp_int = field_data[0, "x"] - field_data[1, "x"]
    amp_list = []
    freq_list = []
    for radius in radii:
        radius_mask = (radial_data[:, 0] > radius - 1) & (
                    radial_data[:, 0] < radius + 1)  # mask?
        field_at_radius = radial_data[:, 2][radius_mask]
        nfft = len(field_at_radius)
        four = np.fft.fft(field_at_radius)
        amplitudes = abs(four[0:int(nfft / 2)]) * (2.0 / nfft)
        frequencies = np.arange(0, int(nfft / 2)) / (nfft * samp_int)
        amp_list.append(amplitudes)
        freq_list.append(frequencies)
    ic(amp_list, freq_list)
    return amp_list, freq_list


def homogeniety_characteriser(field_data):
    """Characterises the homogeneity of a magnet"""
    radii = np.linspace(0, 100, 100)
    dft_helper(field_data, radii)


def centre_helper(field_data, centre=np.nan):
    """Centres the data
    field_data (DataFrame with x,y,field columns)
    """
    # TODO should be lowest change in field for change in theta?
    #  avoid edge somehow
    if not np.isnan(centre):
        centre_coords = centre
    else:
        centre_index = np.argmax(field_data["field"])
        centre_coords = (
            field_data.loc[centre_index, "x"],
            field_data.loc[centre_index, "y"])
    centred_data = field_data.loc[:, "x":"y"] - centre_coords
    full_centred_data = pd.concat(
        (centred_data, field_data["field"]), axis=1)
    return full_centred_data


def square_to_circle_data(xyz_data, radius):
    """Converts the square data to circle with radius specified"""
    radial_data = cartesian_to_cylindrical(xyz_data)
    return radial_data[radial_data[:, 0] < radius]


def calc_drag_force(fourier_data):
    """Calculates the drag force between two magnet
    use mean for one mag inhomogeneity.
    Input: fourier_data (dataframe with multi index, radius then amplitudes and frequencies)
    """
    # TODO vectorize if used
    b_mean = np.mean(fourier_data.loc[:, "field"])  # TODO check data struc
    rq = 0
    qi = 0
    for radius in fourier_data.index.levels[0]:
        q = 0
        for amplitude, index in enumerate(
                fourier_data.loc[radius, "amplitudes"]):
            frequency = fourier_data.loc[radius, "frequencies"][index]
            q += (frequency * amplitude ** 3 *
                  (2 - b_mean * amplitude / (U_0 ** 2 * radius)) / (
                              b_mean * radius))
        rq += radius * q
        qi += q
    return rq / qi


def magnet_comparator(data1, data2, weighting):
    """Compares the inhomogeneities in the magnetic fields of two magnets
    using a determined weighting
    TODO: Implement weightings, add rotation, check mapping
    Simple:
        Add sum of squares
    Centre:
        Sum of squares weighted by distance from centre with gaussian
    Edge:
        Sum of squares weighted by distance from centre with inverse gaussian
    Radial weighting:
        Unrolling radii of magnetic field then taking DFT
        Reducing R=sum(rQ)/sum(Q) over all radii
        Where Q = sum(f*A^3/(r*B1mean)*(2-B1mean*A/(u0^2*r)) for all frequencies
    """
    rotation_resolution = 0.1
    inhomogeneity_list = []
    centre_data1 = centre_helper(data1)
    centre_data2 = centre_helper(data2)
    if weighting == "simple":
        edges = [centre_data1["y"][0], centre_data1["y"].iloc[-1],
                 centre_data1["x"][0], centre_data1["x"].iloc[-1],
                 centre_data2["y"][0], centre_data2["y"].iloc[-1],
                 centre_data2["x"][0], centre_data2["x"].iloc[-1]
                 ]
        largest_radius = np.min(np.abs(edges))
        circle_data1 = cylindrical_to_cartesian(
            square_to_circle_data(centre_data1, largest_radius))
        circle_rad_data2 = square_to_circle_data(centre_data2, largest_radius)
        for theta_multiplier in np.arange(0, 2 * np.pi / rotation_resolution):
            circ_data2_next = circle_rad_data2.copy()
            circ_data2_next[:, 1] = circle_rad_data2[:,
                                    1] + rotation_resolution * theta_multiplier
            rotated_cart_data2 = cylindrical_to_cartesian(circ_data2_next)
            # rotated_cart_data2.sort_values(
            # by=["y", "x"], ignore_index=True, inplace=True)

            difference_in_inhomogeneity = np.sum(
                (circle_data1["field"] - rotated_cart_data2["field"]) ** 2)
            # map points?

            map_ = np.zeros(np.shape(data1))

            inhomogeneity_list.append(difference_in_inhomogeneity)
        # ic(inhomogeneity_list)
        # print(np.min(inhomogeneity_list))
    else:
        radii = np.linspace(0, 100, 100)
        rdata1 = dft_helper(data1, radii)
        rdata2 = dft_helper(data2, radii)


def main():
    """Runs the whole boi"""
    # Todo plot slices, radii
    filename1 = "PM12_N_x"
    filename2 = "PM1"
    data, slice_dir = slice_unpack(filename1)
    slice_plotter(data, slice_dir)
    # data1 = data_unpacker(filename1, "rad1")
    # data2 = data_unpacker(filename2)
    # heatmap(data1)
    # plot_3d(data1)
    # homogeniety_characteriser(split_data[0][0])
    # magnet_comparator(data1[0][0], data2[0][0], "simple")


if __name__ == "__main__":
    main()

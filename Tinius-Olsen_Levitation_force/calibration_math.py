"""Calibration of the Tinius-Olsen force sensor."""

import pandas as pd
import numpy as np
from icecream import ic

GRAVITY = 9.81
TIMINGS_S = [(60, 90), (120, 140), (160, 170), (180, 190),
             (205, 215), (240, 250), (270, 300), (370, 380),
             (465, 490)]
WEIGHTS_G = [222.02, 516.34, 817.34, 523, 910.59, 609.6, 903.94,
             997.29, 387.54]


def load_zero_force(zero_filename: str):
    """Read the zero force from the file."""
    force = np.genfromtxt(zero_filename, skip_header=2, usecols=[2])
    mean_zero_force = np.mean(force)
    std_mean = np.std(force, ddof=1) / np.sqrt(len(force))
    return mean_zero_force, std_mean


def calibration(calib_filename, mean_zero_force):
    """
    Calibrate the force sensor.
    """
    calib_param_list = []
    data = pd.read_csv(
        calib_filename, header=1, delim_whitespace=True)
    data["Force_zeroed"] = data["Force(N)"] - mean_zero_force
    for weight_num, weight in enumerate(WEIGHTS_G):
        start_index = np.argmin(np.abs(
            data["Time(s)"] - TIMINGS_S[weight_num][0]))
        stop_index = np.argmin(np.abs(
            data["Time(s)"] - TIMINGS_S[weight_num][1]))
        force_to_calibrate = data["Force_zeroed"][
                             start_index:stop_index + 1]
        calibration_force = weight * GRAVITY / 1000
        calib_param = np.mean(force_to_calibrate / calibration_force)
        calib_param_list.append(calib_param)
    mean_calibration = np.mean(calib_param_list)
    std_mean = np.std(calib_param_list, ddof=1) / np.sqrt(
        len(calib_param_list))
    return mean_calibration, std_mean


def main():
    """Runs all necessary functions."""
    zero_force, zero_err = load_zero_force(
        "Measurements/zero_force.txt")
    print(f"Zero force: {zero_force} +/- {zero_err}")
    mean_calibration, calibration_err = calibration(
        "Measurements/20231127_1023calibration.txt", zero_force)
    print(f"Calibration: {mean_calibration} +/- {calibration_err}")


if __name__ == '__main__':
    main()

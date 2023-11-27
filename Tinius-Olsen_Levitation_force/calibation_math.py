import pandas as pd
import numpy as np

GRAVITY = 9.81
TIMINGS_S = [(600, 900), (1200, 1400), (1600, 1700), (1800, 1900), (2050, 2150), 
           (2400, 2500), (2700, 3000), (3700, 3800), (4650, 4900)]
WEIGHTS_G = [222.02, 516.34, 817.34, 523, 910.59, 609.6, 903.94, 997.29, 387.54]

def zero_force(zero_filename):
    force = pd.read_csv(zero_filename, usecols=2, header=1, delimiter=" ")
    mean_zero_force = np.mean(force)
    std_mean = np.std(force)/sqrt(len(force))
    return mean_zero_force, std_mean


def calibration(calib_filename):
    calib_param_list = []
    data = pd.read_csv(calib_filename, header=1, usecols=[0, 2], delimiter=" ")
    for weight, weight_num in enumerate(WEIGHTS_G):
        start_index = pd.argmin(data["Time(s)"]-TIMINGS_S[weight_num][0])
        stop_index = pd.argmin(data["Time(s)"]-TIMINGS_S[weight_num][1])
        force_to_calibrate = data["Force(N)"][start_index:stop_index+1]
        calibration_force = weight * GRAVITY / 1000
        calib_param = np.mean(force_to_calibrate/calibration_force)
        calib_param_list.append(calib_param)
    return calib_param_list


def main():
    print(zero_force("zero_force.txt"))
    print(calibration("20231127_1023calibration.txt"))

if __name__ == '__main__':
   main()
    
"""Script to read TDMS files and convert to pandas dataframe"""

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from icecream import ic
from nptdms import TdmsFile
import tempfile


def read_rpm():
    """Read the rpm data from the file"""
    file = '1st run_90000rpm_spindown/09-02-2024_13-59-41.323.tdms'
    with TdmsFile.open(file) as tdms_file:
        # for group in tdms_file.groups():
        #     print(group)
        #     for channel in tdms_file[group.name].channels():
        #         print(channel)
        rpm = tdms_file['RPM']['RPM']
        time = tdms_file['RPM']['Time']
        plt.plot(time[:], rpm[:])
        plt.grid(True)
        plt.show()


def read_volts():
    """Read the voltage data from the file"""
    file = '2nd run/09-02-2024_14-14-20.564.tdms'
    with TdmsFile.open(file) as tdms_file:
        times = tdms_file['Phase voltages and currents']['Time (s) ']
        va = tdms_file['Phase voltages and currents']['Va']
        vb = tdms_file['Phase voltages and currents']['Vb']
        vc = tdms_file['Phase voltages and currents']['Vc']
        ia = tdms_file['Phase voltages and currents']['Ia']
        ib = tdms_file['Phase voltages and currents']['Ib']
        ic = tdms_file['Phase voltages and currents']['Ic']
        print("Loaded data")
        new_times = np.empty((len(times[:]),), dtype=float)
        for chunk_no, chunk in enumerate(times.data_chunks()):
            new_times[chunk_no * len(chunk[:]):
                      (chunk_no + 1) * len(chunk[:])] = chunk[:] + np.max(
                chunk[:]) * chunk_no
        print("Adjusted times")
        m = 100
        newia = ia[:].reshape(-1, m).mean(axis=1)
        newib = ib[:].reshape(-1, m).mean(axis=1)
        newic = ic[:].reshape(-1, m).mean(axis=1)
        newva = va[:].reshape(-1, m).mean(axis=1)
        newvb = vb[:].reshape(-1, m).mean(axis=1)
        newvc = vc[:].reshape(-1, m).mean(axis=1)
        np.savetxt("Averaged_values_spindown.csv", np.column_stack(
            (new_times[::m], newia, newib, newic, newva, newvb, newvc)),
                   header="Time,Ia,Ib,Ic,Va,Vb,Vc", delimiter=",")


def main():
    """Tadaa"""
    # read_rpm()
    read_volts()

if __name__ == '__main__':
    main()

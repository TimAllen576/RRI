""" Converts all .txt files in the Measurements folder to .csv and
.xlsx files. Also calibrates the forces while its there."""

import os
import pandas as pd


zero_force = -0.34456794520547945
calibration = 1/0.4945935055768483

folder_path = 'Measurements'
with pd.ExcelWriter('All_measures.xlsx') as writer:
    for filename in os.listdir(folder_path):
        if filename.endswith('.txt'):
            file_path = os.path.join(folder_path, filename)
            df = pd.read_csv(file_path, header=1, delim_whitespace=True)
            df["Force(N)"] = (df["Force(N)"] - zero_force) * calibration
            df.to_csv(f'{filename}.csv', index=False)
            df.to_excel(writer, sheet_name=filename, index=False)

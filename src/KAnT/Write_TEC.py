import numpy as np
import cantera as ct
import os, sys
masterpath = os.environ.get("ATLASDIR")
if masterpath is None:
    print("ATLAS environment variable is not set.")
    sys.exit(1)
datapath = masterpath + '/database/'
ct.add_directory(datapath+'Chemistry')

def write_1D(models, x, y, xlabel, ylabel):

    # Write the data to a file in Tecplot-readable format
    filename =  "KAnT-out.tec"
    with open(filename, 'w') as f:
        f.write("TITLE = \"KAnT Output\"\n")
        f.write(f"VARIABLES = \"{xlabel}\"\"{ylabel}\"\n")

        for model in models:
            gas = ct.Solution(model+'.yaml')
            if isinstance(x, np.ndarray):
                xx = x
            else:
                xx = x[model]
            f.write(f"ZONE T={gas.name}\n")
            f.write(f"I={len(xx)}, F=POINT\n")
            for i in range(len(xx)):
                f.write(f'{xx[i]:<12}  {y[model][i]:.20E}\n')
from ORION import read_TEC
from reactants import Reactant, ReactantStore
import cantera as ct
import numpy as np

def setup_TEC(file, model):

    gas = ct.Solution(model)  # replace with your YAML file name)

    # Read the Tecplot file
    [x,y,z,vini,varnames] = read_TEC(file)

    nb = len(vini)
    nsc = sum(1 for name in varnames if name.startswith('r'))

    var_names = ['x', 'y', 'z']
    for i in range(nsc):
        var_names.append(f'rho({i+1})')
    var_names += ['p', 'T', 'R']

    N = nsc + 3 # p, T, R
    var = []
    stores = []

    for b in range(nb):
        Nx, Ny, Nz = vini[b][0].shape
        var_b = [np.zeros((Nx, Ny, Nz)) for _ in range(N)]
        for k in range(Nz):
            for j in range(Ny):
                for i in range(Nx):

                    store = ReactantStore()
                    store.index = (b,i,j,k)

                    p_index = varnames.index("p")-3
                    pressure = vini[b][p_index][i,j,k]

                    try:
                        T_index = varnames.index("T")-3
                        temperature = vini[b][T_index][i,j,k]
                    except:
                        density = sum(vini[b][s][i,j,k] for s in range(nsc))
                        gas.Y = [vini[b][s][i,j,k] for s in range(nsc)]
                        temperature = pressure / ( density * ct.gas_constant / gas.mean_molecular_weight )

                    var_b[-1+nsc+1][i,j,k] = pressure

                    store.pressure = pressure
                    for s in range(nsc):
                        r = Reactant()
                        rstr = gas.species_names[s] + ":" + str(vini[b][s][i,j,k])
                        r.build(rstr, "N", temperature)
                        store.add_reactant(r)

                    stores.append(store)
        var.append(var_b)

    return stores, x, y, z, var, var_names

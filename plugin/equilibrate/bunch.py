import numpy as np
import cantera as ct
from concurrent.futures import ProcessPoolExecutor

# Worker function — must be top-level (not nested inside another function)
def process_store(store_data):
    store, model, species = store_data
    b, i, j, k = store.index
    gas = store.build_cantera_solution(model=model, species=species)
    gas.equilibrate('HP', solver='vcs', rtol=1e-6, max_steps=1000)
    return b, i, j, k, gas.Y, gas.T, ct.gas_constant / gas.mean_molecular_weight 

def run_parallel(stores, args, v):
    # Pack input data for each store
    input_data = [(store, args.model, args.species) for store in stores]

    with ProcessPoolExecutor() as executor:
        results = list(executor.map(process_store, input_data))

    for b, i, j, k, Y, T, R in results:
        for s, y in enumerate(Y):
            v[b][s][i, j, k] = y
        v[b][-2][i, j, k] = T
        v[b][-1][i, j, k] = R


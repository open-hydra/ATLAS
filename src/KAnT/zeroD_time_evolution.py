import numpy as np
import cantera as ct
import sys, os, re
from units import convert2si
from phase_tools import *
masterpath = os.environ.get("ATLASDIR")
if masterpath is None:
    print("ATLAS environment variable is not set.")
    sys.exit(1)
datapath = masterpath + '/database/'
ct.add_directory(datapath+'Chemistry')

#################################################################################

def run_all(models, reactor_type, fuel_string, oxi_string, pressures, mixture_ratio, temperatures):

    fuel_composition = re.findall(r'{(.*?):(.*?)}', fuel_string[1])
    fuel_dict = {species: float(value) for species, value in fuel_composition}

    oxi_composition = re.findall(r'{(.*?):(.*?)}', oxi_string[1])
    oxi_dict = {species: float(value) for species, value in oxi_composition}

    Tout = {}
    pout = {}

    for model in models:
        print(' -- Processing: ',model)

        new_mechanism = add_species('N2',ct.Solution(model+'.yaml'),'nasa9')
        new_mechanism = add_species('Ar',new_mechanism,'nasa9')
        Tout[model] = []
        pout[model] = []

        # Loop over temperatures
        for temperature in temperatures:
            for pressure in pressures:
                press = convert2si(pressure, 'bar')
                for mr in mixture_ratio:

                    tout = []

                    setup_mixture(new_mechanism, fuel_dict, oxi_dict, mr)
                    new_mechanism.TP = temperature, press

                    if reactor_type=='HP':
                      r = ct.IdealGasConstPressureReactor(contents=new_mechanism, name="Batch Reactor")
                    else:
                      r = ct.IdealGasReactor(contents=new_mechanism, name="Batch Reactor")
                    reactor_network = ct.ReactorNet([r])
                    # Set the ODE tollerances and max time step
                    rtol = 1.e-7
                    atol = 1.e-7
                    reactor_network.rtol, reactor_network.atol = rtol, atol
                    reactor_network.max_time_step = 1e-5

                    time = 0.0
                    tout.append(time)
                    Tout[model].append(r.thermo.T)
                    pout[model].append(r.thermo.P)

                    # rho = gas.density                       # [kg/m³]
                    # cv = gas.cv_mass                       # [J/(kg·K)]
                    # h_k = gas.partial_molar_enthalpies             # [J/kmol]
                    # omega_dot = gas.net_production_rates  # [kmol/m³/s]
                    # W_k = gas.molecular_weights            # [kg/kmol]

                    # # Compute dT/dt
                    # dTdt = -np.dot(h_k, omega_dot) / (rho * cv)

                    # species_index = 8
                    # species_name = gas.species_name(species_index)

                    # print(f"Computing production rate for species {species_name} (index {species_index})")

                    # # Get all rates 
                    # Rf = gas.forward_rates_of_progress        # [kmol/m³/s]
                    # Rr = gas.reverse_rates_of_progress        # [kmol/m³/s]
                    # Rnet = gas.net_rates_of_progress          # [kmol/m³/s]
                    # kf = gas.forward_rate_constants           # [varies]
                    # Kc = gas.equilibrium_constants            # [varies]
                    # kb = kf / Kc                              # [same units as kf]

                    # conc = gas.concentrations                # [kmol/m³]

                    # # Loop over all reactions
                    # omega = 0.0
                    # for i, rxn in enumerate(gas.reactions()):
                    #     nu_p = rxn.products.get(species_name, 0.0)
                    #     nu_r = rxn.reactants.get(species_name, 0.0)
                    #     nu_ki = nu_p - nu_r

                    #     if nu_ki != 0:
                    #         print(f"\nReaction {i}: {rxn.equation}")
                    #         print(f"  ν_ki = {nu_ki:+.1f}")
                    #         print(f"  Forward rate: Rf = {Rf[i]:.3e} kmol/m³/s")
                    #         print(f"  Reverse rate: Rr = {Rr[i]:.3e} kmol/m³/s")
                    #         print(f"  Net rate:     Rnet = {Rnet[i]:.3e} kmol/m³/s")
                    #         print(f"  kf = {kf[i]:.3e},  kb = {kb[i]:.3e}")

                    #         print(f"  Reactant concentrations:")
                    #         for sp, coeff in rxn.reactants.items():
                    #             print(f"    {sp}: {conc[gas.species_index(sp)]:.3e} kmol/m³")

                    #         print(f"  Product concentrations:")
                    #         for sp, coeff in rxn.products.items():
                    #             print(f"    {sp}: {conc[gas.species_index(sp)]:.3e} kmol/m³")

                    #         contrib = nu_ki * Rnet[i]
                    #         print(f"  Contribution to ω̇_{species_index}: {contrib:.3e} kmol/m³/s")

                    # print(f"\nTotal net production rate ω̇_{species_index} = {omega:.3e} kmol/m³/s")

                    # # Optional: compare with Cantera's built-in value
                    # omega_dot = gas.net_production_rates[species_index]
                    # print(f"Check: Cantera ω̇_{species_index} = {omega_dot:.3e} kmol/m³/s")

                    # print(reactor.thermo.T,'ccc')
                    # print(cv)
                    # print(omega_dot*gas.molecular_weights)
                    # print(dTdt)
                    # print('zzz')


                    for _ in range(1000):
                        time += 0.4/1000
                        reactor_network.advance(time)

                        tout.append(time)
                        Tout[model].append(r.thermo.T)
                        pout[model].append(r.thermo.P)

                        # rho = gas.density                       # [kg/m³]
                        # cv = gas.cv_mass                       # [J/(kg·K)]
                        # h_k = gas.partial_molar_enthalpies             # [J/kmol]
                        # omega_dot = gas.net_production_rates  # [kmol/m³/s]
                        # W_k = gas.molecular_weights            # [kg/kmol]

                        # # Compute dT/dt
                        # dTdt = -np.dot(h_k, omega_dot) / (rho * cv)

                        # print(cv)
                        # print(omega_dot)
                        # print(dTdt)

    tout = np.array(tout)

    return tout, pout, Tout

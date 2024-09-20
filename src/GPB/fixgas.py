import cantera as ct

# Define the specific heat capacity (Cp) in J/(kg*K)
# Define the molecular weight of the species in kg/kmol (or g/mol)
def build_thermo(T_low,T_high,names,constant_cp_value,molecular_weight):

    P_ref = ct.one_atm
    h0 = 0  # Enthalpy at reference temperature in J/kmol
    s0 = 10  # Entropy at reference temperature in J/kmol-K

    dummy_species_list = []

    for i in range(len(constant_cp_value)):

        cp_molar = constant_cp_value[i] * molecular_weight[i]
        # Coefficients for ConstantCp: [T_ref, h0, s0, Cp]
        coeffs = (0, h0, s0, cp_molar)

        # Il peso molecolare deve essere definito tramite la composizione elementale.
        # Per imporre un peso molecolare qualsiasi si sfrutta un numero di atomi di
        # idrogeno pari al peso molecolare desiderato diviso quello di 1 atomo di H
        fixgas_species = ct.Species(names[i], 'H:'+str(molecular_weight[i]/1.008))
        fixgas_species.thermo = ct.ConstantCp(T_low=T_low, T_high=T_high, P_ref=P_ref, coeffs=coeffs)

        dummy_species_list.append(fixgas_species)

    fixgas_phase = ct.Solution(name='constant-cp species', thermo='ideal-gas', species=dummy_species_list)

    return fixgas_phase
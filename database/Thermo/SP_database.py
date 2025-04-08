

def compute_properties_from_database(name,temperatures):

    if name=='uranio':
        cp = temperatures*2
        rho = temperatures*3
        k = temperatures*4
        e = temperatures*5

    return cp, rho, k, e

import os 
def compute_properties_from_database(name,temperatures):

    if name == 'UC':

        file_path = os.path.dirname(os.path.realpath(__file__))

        kT = open(file_path + '/kT_UC.dat', 'r')
        num = int(kT.readline())
        T_dat = []
        k_dat = []

        for i in range(num):
            dat = kT.readline().split(' ')
            T_dat.append(float(dat[0]))
            k_dat.append(float(dat[1]))

        kT.close()

        k   = 0.0 * temperatures
        cp  = 0.0 * temperatures
        rho = 0.0 * temperatures
        e   = 0.0 * temperatures
        for i in range(0, len(temperatures)):

            for j in range(0, len(T_dat)):

                if temperatures[i] <= T_dat[0]:
                    k[i] = k_dat[0]
                elif temperatures[i] >= T_dat[-1]:
                    k[i] = k_dat[-1]
                elif temperatures[i] < T_dat[j]:
                    k[i] = k_dat[j-1]+(temperatures[i]-T_dat[j-1])/(T_dat[j]-T_dat[j-1])*(k_dat[j]-k_dat[j-1])
                    break
            
            cp[i]  = 300.0    # [J/kg*K]
            rho[i] = 1000.0   # [kg/m^3]
            
            if (i > 0):
                e[i] = e[i-1] + rho[i]*cp[i]*(temperatures[i]-temperatures[i-1])
            else:
                e[i] = 0.0


    elif name == 'Mo30W-60UN':
        
        wt_Mo = 0.7
        wt_W  = 0.3
        vp = 0.6
        
        k_W  = 0.0 * temperatures
        for i in range(0, len(temperatures)):
            if temperatures[i] < 890:
                k_W[i] = 165.4 - 85.57*(temperatures[i]/1e3) + 33.51*(temperatures[i]/1e3)**2
            else:
                k_W[i] = 133.82 - 15.57*(temperatures[i]/1e3)

        k_Mo = 0.0 * temperatures
        for i in range(0, len(temperatures)):
            if temperatures[i] < 50:
                k_Mo[i] = - 4.545 + 16.186*temperatures[i] - 0.0605*temperatures[i]**2 - 0.00298*temperatures[i]**3 
            elif temperatures[i] >= 50 and temperatures[i] < 150:
                k_Mo[i] = 522.44 - 5.4776*temperatures[i] + 0.02*temperatures[i]**2
            else:
                k_Mo[i] = 153.29 - 0.0513*temperatures[i] + 9*1e-6*temperatures[i]**2

        k_UN = 0.0 * temperatures
        for i in range(0, len(temperatures)):
            if temperatures[i] < 1910:
                k_UN[i] = 1.43*temperatures[i]**0.39
            else:
                k_UN[i] = 27.0

        k   = 0.0 * temperatures
        cp  = 0.0 * temperatures
        rho = 0.0 * temperatures
        e   = 0.0 * temperatures
        for i in range(0, len(temperatures)):
            k_matrix = wt_Mo * k_Mo[i] + wt_W * k_W[i]

            k[i] = k_UN[i] + (1 - vp) * (k_matrix - k_UN[i])*(k_UN[i]/k_matrix)**(1/3)
            
            cp[i]   = 300.0    # [J/kg*K]
            rho[i]  = 1000.0   # [kg/m^3]
            
            if (i > 0):
                e[i] = e[i-1] + rho[i]*cp[i]*(temperatures[i]-temperatures[i-1])
            else:
                e[i] = 0.0


    elif name == 'Mo30W':
        
        wt_Mo = 0.7
        wt_W  = 0.3
        
        k_W  = 0.0 * temperatures
        for i in range(0, len(temperatures)):
            if temperatures[i] < 890:
                k_W[i] = 165.4 - 85.57*(temperatures[i]/1e3) + 33.51*(temperatures[i]/1e3)**2
            else:
                k_W[i] = 133.82 - 15.57*(temperatures[i]/1e3)

        k_Mo = 0.0 * temperatures
        for i in range(0, len(temperatures)):
            if temperatures[i] < 50:
                k_Mo[i] = - 4.545 + 16.186*temperatures[i] - 0.0605*temperatures[i]**2 - 0.00298*temperatures[i]**3 
            elif temperatures[i] >= 50 and temperatures[i] < 150:
                k_Mo[i] = 522.44 - 5.4776*temperatures[i] + 0.02*temperatures[i]**2
            else:
                k_Mo[i] = 153.29 - 0.0513*temperatures[i] + 9*1e-6*temperatures[i]**2


        k   = 0.0 * temperatures
        cp  = 0.0 * temperatures
        rho = 0.0 * temperatures
        e   = 0.0 * temperatures
        for i in range(0, len(temperatures)):
            
            k[i] = wt_Mo * k_Mo[i] + wt_W * k_W[i]
            cp[i]   = 300.0    # [J/kg*K]
            rho[i]  = 1000.0   # [kg/m^3]
            if (i > 0):
                e[i] = e[i-1] + rho[i]*cp[i]*(temperatures[i]-temperatures[i-1])
            else:
                e[i] = 0.0


    elif name == 'ZrC':
        k   = 0.0 * temperatures
        cp  = 0.0 * temperatures
        rho = 0.0 * temperatures
        e   = 0.0 * temperatures
        for i in range(0, len(temperatures)):
            k[i]    = 0.5209 + 9.812e-4*temperatures[i] + 1.045e-7*temperatures[i]**2  # [W/m*K]
            cp[i]   = 300.0    # [J/kg*K]
            rho[i]  = 1000.0   # [kg/m^3]
            if (i > 0):
                e[i] = e[i-1] + rho[i]*cp[i]*(temperatures[i]-temperatures[i-1])
            else:
                e[i] = 0.0

    elif name == 'ZrHx':
        k   = 0.0 * temperatures
        cp  = 0.0 * temperatures
        rho = 0.0 * temperatures
        e   = 0.0 * temperatures
        for i in range(0, len(temperatures)):
            k[i]    = 16.0     # [W/m*K]
            cp[i]   = 300.0    # [J/kg*K]
            rho[i]  = 1000.0   # [kg/m^3]
            if (i > 0):
                e[i] = e[i-1] + rho[i]*cp[i]*(temperatures[i]-temperatures[i-1])
            else:
                e[i] = 0.0

    elif name == 'Zircaloy':
        k   = 0.0 * temperatures
        cp  = 0.0 * temperatures
        rho = 0.0 * temperatures
        e   = 0.0 * temperatures
        for i in range(0, len(temperatures)):
            k[i]    = 131.2 - 0.08432*temperatures[i] + 1.96e-5*temperatures[i]**2 # [W/m*K]
            cp[i]   = 300.0    # [J/kg*K]
            rho[i]  = 1000.0   # [kg/m^3]
            if (i > 0):
                e[i] = e[i-1] + rho[i]*cp[i]*(temperatures[i]-temperatures[i-1])
            else:
                e[i] = 0.0

    elif name == 'Graphite':
        k   = 0.0 * temperatures
        cp  = 0.0 * temperatures
        rho = 0.0 * temperatures
        e   = 0.0 * temperatures
        for i in range(0, len(temperatures)):
            k[i]    = 134.0 - 0.1074*temperatures[i] + 3.719e-5*temperatures[i]**2 # [W/m*K]
            cp[i]   = 300.0    # [J/kg*K]
            rho[i]  = 1000.0   # [kg/m^3]
            if (i > 0):
                e[i] = e[i-1] + rho[i]*cp[i]*(temperatures[i]-temperatures[i-1])
            else:
                e[i] = 0.0

    return cp, rho, k, e
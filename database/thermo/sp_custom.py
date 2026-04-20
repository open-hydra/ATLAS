
import os 
def compute_properties_from_database(name,temperatures):

    if name == 'UC':

        # k(T) data for UC moved to module-level constants at file end
        T_dat = KTU_T_DAT
        k_dat = KTU_K_DAT

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


# Module-level embedded k(T) data for UC (moved from inline location)
KTU_T_DAT = [
    98.84678747940691,
    164.7446457990115,
    234.7611202635914,
    329.4892915980230,
    415.9802306425040,
    506.5897858319604,
    564.2504118616145,
    638.3855024711696,
    720.7578253706754,
    790.7742998352553,
    869.0280065897858,
    943.1630971993410,
    1033.772652388797,
    1112.026359143327,
    1206.754530477759,
    1276.771004942339,
    1367.380560131795,
    1453.871499176276,
    1528.006589785832,
    1610.378912685337,
    1684.514003294892,
    1766.886326194398,
    1865.733113673805,
    1952.224052718286,
    2038.714991762767,
    2121.087314662273,
    2191.103789126853,
    2277.594728171334,
    2351.729818780889,
    2438.220757825370,
    2528.830313014827,
    2800.0,
]

KTU_K_DAT = [
    12.564570095017498,
    12.500550704393461,
    12.3734888419193,
    12.436857507371341,
    12.564570095017498,
    12.628917349787105,
    12.758602176758451,
    12.955630656184326,
    13.155701806050665,
    13.42727769909136,
    13.774644790939321,
    13.987363808288592,
    14.349220470345522,
    14.720438456356666,
    15.101259946155567,
    15.651018177675914,
    16.13814156551242,
    16.6404262158485,
    17.1583440088819,
    17.692381511642754,
    18.33646898552934,
    19.004004330113535,
    19.898095374310625,
    20.728095845618903,
    21.59271776030721,
    22.378796165152266,
    23.075315387091496,
    23.915367450575868,
    25.040525890071685,
    26.3528943217433,
    28.01884123810662,
    30.0,
]
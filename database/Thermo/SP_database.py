
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

        k = 0.0 * temperatures
        cp = 0.0 * temperatures
        rho = 0.0 * temperatures
        e = 0.0 * temperatures
        for i in range(0, len(temperatures)):

            for j in range(0, len(T_dat)):

                if temperatures[i] < T_dat[0]:
                    k[i] = k_dat[0]
                elif temperatures[i] > T_dat[-1]:
                    k[i] = k_dat[-1]
                elif temperatures[i] < T_dat[j]:
                    k[i] = k_dat[j-1]+(temperatures[i]-T_dat[j-1])/(T_dat[j]-T_dat[j-1])*(k_dat[j]-k_dat[j-1])
                    break
            
            cp[i] = 300.0     # [J/kg*K]
            rho[i] = 1000.0   # [kg/m^3]
            
            if (i > 0):
                e[i] = e[i-1] + rho[i]*cp[i]*(temperatures[i]-temperatures[i-1])
            else:
                e[i] = 0.0

    return cp, rho, k, e
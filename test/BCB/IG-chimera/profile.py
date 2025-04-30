import numpy as np

theta = np.linspace (np.pi, 0.0, 1000)
r_int = 0.1e-1
r_med = 0.3e-1
r_ext = 1.0e-1

with open('circ_int.dat','w') as f:
    for i in range(len(theta)):
        x = r_int*np.cos(theta[i])
        y = r_int*np.sin(theta[i])
        f.write(str(x) + ' ' + str(y) + '\n') 
f.close()

with open('circ_med.dat','w') as f:
    for i in range(len(theta)):
        x = r_med*np.cos(theta[i])
        y = r_med*np.sin(theta[i])
        f.write(str(x) + ' ' + str(y) + '\n') 
f.close()


with open('circ_ext.dat','w') as f:
    for i in range(len(theta)):
        x = r_ext*np.cos(theta[i])
        y = r_ext*np.sin(theta[i])
        f.write(str(x) + ' ' + str(y) + '\n') 
f.close()

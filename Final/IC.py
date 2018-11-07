import h5py
import numpy as np

#Define Coordinate Mesh
N = 256
x = np.linspace(0,1-1/N,N) + 1./N/2
y = np.linspace(0,1-1/N,N) + 1./N/2
z = np.linspace(0,1-1/N,N) + 1./N/2
xx,yy,zz = np.meshgrid(x,y,z)



#Define Grid
Grid = np.zeros(xx.shape)
Vx   = np.zeros(xx.shape)
Vy   = np.zeros(xx.shape)
P    = np.zeros(xx.shape)

#Kelvin-Helmholtz Perturbation: Perturbation Parameters, Initial Conditions
dv = 0.04 # (was 0.04 for rho = 2, 1)
vx = 0.5
rho = [2.0, 1.0]
g   = 10

#ied = (2.5)/rho/(g-1)
R1 = 0.25 > xx > 0.75
R2 = (1-(0.25 > xx > 0.75)).astype(bool)
Grid[R1] = rho[0]
Grid[R2] = rho[1]
Vx[R1]   = vx
Vx[R2]   = -vx
Vy       = dv*np.sin(yy*2*np.pi)







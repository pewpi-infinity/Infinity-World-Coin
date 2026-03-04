#!/usr/bin/env python3
import numpy as np
import matplotlib.pyplot as plt
from mpl_toolkits.mplot3d import Axes3D

class Atom:
    def __init__(self, protons, neutrons, electrons):
        self.protons = protons
        self.neutrons = neutrons
        self.electrons = electrons

def print_atoms():
    hydrogen = Atom(1, 0, 1)
    gold = Atom(79, 118, 79)
    print("Hydrogen: Protons =", hydrogen.protons,
          ", Neutrons =", hydrogen.neutrons,
          ", Electrons =", hydrogen.electrons)
    print("Gold: Protons =", gold.protons,
          ", Neutrons =", gold.neutrons,
          ", Electrons =", gold.electrons)

def simulate_watsons(num_watsons=150, num_steps=120, dt=0.02, softening=0.25, k_attract=0.15):
    positions = np.random.rand(num_watsons, 3) * 2 - 1
    velocities = (np.random.rand(num_watsons, 3) - 0.5) * 0.1
    for _ in range(num_steps):
        centroid = positions.mean(axis=0)
        diffs = centroid - positions
        dist2 = np.sum(diffs**2, axis=1) + softening**2
        inv_r3 = 1.0 / np.sqrt(dist2**3)
        accel = k_attract * (diffs * inv_r3[:, None])
        velocities += accel * dt
        positions += velocities * dt
        velocities += (np.random.rand(num_watsons, 3) - 0.5) * (0.002)
    return positions

def plot_compression_spectrum():
    materials = ['Hydrogen', 'Diamond', 'Gold']
    compression = [1, 5, 79]
    xvals = np.arange(len(materials))
    plt.figure()
    plt.plot(xvals, compression, marker='o')
    plt.xticks(xvals, materials)
    plt.xlabel('Material')
    plt.ylabel('Compression Level')
    plt.title('Watson Compression Spectrum')
    plt.tight_layout()
    plt.show()

def plot_watson_positions(positions):
    fig = plt.figure()
    ax = fig.add_subplot(111, projection='3d')
    ax.scatter(positions[:,0], positions[:,1], positions[:,2], s=10, alpha=0.7)
    ax.set_title("Watson Particle Positions After Simulation")
    ax.set_xlabel('X')
    ax.set_ylabel('Y')
    ax.set_zlabel('Z')
    plt.tight_layout()
    plt.show()

if __name__ == "__main__":
    print_atoms()
    pos = simulate_watsons()
    plot_compression_spectrum()
    plot_watson_positions(pos)

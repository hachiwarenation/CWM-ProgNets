""" idk tbh """
# !/usr/bin/python3
import numpy as np
import matplotlib.pyplot as plt


# parameters to modify REMEMBER TO CHANGE WHEN SWAPPING TO/FROM CDF
filenames=["processed_ping.txt"]
labels=['i=0.01']
xlabel = 'time'
ylabel = 'proportion'
title='RTT for each ping'
fig_name='testc1.png'
bins=1000 #adjust the number of bins to your plot

for i in range(len(filenames)):
    t = np.loadtxt(filenames[i], dtype="float")
    #x = [p for p in range(1,len(t)+1)]

    #plt.plot(t[:,0], t[:,1], label=labels[i])  # Plot some data on the (implicit) axes.

    #Comment the line above and uncomment the line below to plot a CDF
    plt.hist(t[:,1], bins, density=True, histtype='step', cumulative=True, label=labels[i])


plt.xlabel(xlabel)
plt.ylabel(ylabel)
plt.title(title)
plt.legend()
plt.savefig(fig_name)
plt.show()

""" idk tbh """
# !/usr/bin/python3
import numpy as np
import matplotlib.pyplot as plt


# parameters to modify REMEMBER TO CHANGE WHEN SWAPPING TO/FROM CDF
filenames=['s1.txt',"s2.txt",'s3.txt']
labels=['100kb/s','1Mb/s','100Mb/s']
xlabel = 'time, s'
ylabel = 'data transfer, KB'
title='data transfer at different bandwidths, UDP'
fig_name='testi3_2.png'
bins=1000 #adjust the number of bins to your plot

for i in range(len(filenames)):
    t = np.loadtxt(filenames[i], dtype="float")
    x = [0.5*p for p in range(1,len(t)+1)]

    plt.semilogy(x, t, label=labels[i])  # Plot some data on the (implicit) axes.

    #Comment the line above and uncomment the line below to plot a CDF
    #plt.hist(t[:,1], bins, density=True, histtype='step', cumulative=False, label=labels[i])


#plt.axis([x[0],x[-1],900,980])

plt.xlabel(xlabel)
plt.ylabel(ylabel)
plt.title(title)
plt.legend()
plt.savefig(fig_name)
plt.show()

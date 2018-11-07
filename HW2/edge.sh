#!/bin/bash
#PBS -l nodes=1
#PBS -l ncpus=8
#PBS -l walltime=00:05:00
#PBS -d .

regent edge.rg -p 1 -ll:cpu 1 -i images/earth.png
regent edge.rg -p 2 -ll:cpu 2 -i images/earth.png
regent edge.rg -p 4 -ll:cpu 4 -i images/earth.png
regent edge.rg -p 8 -ll:cpu 8 -i images/earth.png




#!/bin/bash

#############################################################################################
## NEED TO ALTER PATH WHERE HIGHLIGHTED IN SCRIPT                                          ##
## NEED TO HAVE DIRECTORY WITH INSANE.PY MARTINI_V3.ITP AND MDP FILES                      ##
#############################################################################################

##Make repeats each with seperate insane builds##
for i in $(seq 1 $1)
do 

mkdir Repeat_$i
cd Repeat_$i

cp ../martini_v3.itp .

##Make bilayer##
path/to/python2 insane3.py -salt 0.15 -sol W -u PIMD:22 -u PIM6:11 -u PID6:10 -u TBPI:13 -u CARD:24 -u TBPE:20 -l PIMA:90 -l PIMD:10 -x 20 -y 20 -z 15 -o CG-system.gro -p topol.top -center -au 0.92 -a 1.13  ### ALTER PATH HERE

##Fix M3 ion names##
sed -i 's/TNA/NA/g' CG-system.gro
sed -i 's/TNA/NA/g' topol.top 
sed -i 's/TCL/CL/g' CG-system.gro
sed -i 's/TCL/CL/g' topol.top

##Neutralise system##
gmx grompp -f em.mdp -o neutral -c CG-system.gro  -maxwarn -1
gmx genion -s neutral -p topol.top -neutral -o neutral.pdb -conc 0.15 -pname NA -nname CL << EOD
W
EOD

##Minimise system##
gmx grompp -f ../em.mdp -o em -c neutral.pdb  -maxwarn -1
gmx mdrun -deffnm em -c CG-system.pdb -v -nt 8
gmx trjconv -f CG-system.pdb -o CG-system.pdb -pbc res -s em.tpr -conect <<EOD
0
EOD
gmx make_ndx -f CG-system.pdb -o sys.ndx << EOD
del 0-100
rTB*|rPOP*|rPIP*|rDHP*|rDPP*|rDMP*|rDOP*|rBOG*|rCHO*|rDDM*|rDSP*|rTOC*|rCAR*|rDLP*|rSQD*|rDGD*|rLMG*|rrMAG*|rLPA*|rUPP*|rCYST*|rCYSD*|rPAM*|rLIP*|rREM*|rRAM*|rCL1*|rDPS*|rAPG|rKPG|rPIM*|rTMM*|rPID*
rW*|rION
name 0 LIPID
name 1 SOL_ION
q
EOD

mkdir MD

##Make production tpr##
gmx grompp -f 10us-martini-2021.mdp -o MD/md -c CG-system.pdb -maxwarn -1 -n sys.ndx

cd ../

done

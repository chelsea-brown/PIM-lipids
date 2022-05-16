#!/bin/bash

#############################################################################################
## NEED TO HAVE MEMEMBED DOWNLOADED: https://github.com/timnugent/memembed                 ##
## NEED TO HAVE MARTINIZE2 INSTALLED: https://github.com/marrink-lab/vermouth-martinize    ##
## NEED TO ALTER PATH WHERE HIGHLIGHTED IN SCRIPT                                          ##
## NEED TO HAVE DIRECTORY WITH PROTEIN.PDB INSANE.PY MARTINI_V3.ITP AND MDP FILES          ##
#############################################################################################


if [[ $# -ne 2 ]] ; then
    echo "Usage: bash setup-system.sh protein.pdb num-repeats"
    exit 0
fi

path/to/memembed -n out -o memembed.pdb $1   ### ALTER PATH HERE

grep -v DU memembed.pdb > cut.pdb

gmx editconf -f cut.pdb -o centered.pdb -c -d 3 -resnr 1
 
gmx make_ndx -f memembed.pdb <<EOD
del 0
del 1-100
rDUM
q
EOD

gmx confrms -f2 memembed.pdb -f1 centered.pdb -one -o pre_aligned.pdb  <<EOD
3
3
EOD

grep -v END centered.pdb > centered.txt 
grep DUM pre_aligned.pdb > dum.txt
cat centered.txt dum.txt > aligned.pdb

gmx editconf -f aligned.pdb -o protein.pdb -resnr 1 -n -label A <<EOD
0
EOD

cutx=`grep CRYST centered.pdb | cut -c9-15`
x=`bc -l <<< "scale=3; $cutx / 10"`
cuty=`grep CRYST centered.pdb | cut -c18-24`
y=`bc -l <<< "scale=3; $cuty / 10"`
cutz=`grep CRYST centered.pdb | cut -c27-33`
z=`bc -l <<< "scale=3; $cutz / 10"`

gmx traj -f aligned.pdb -com -s aligned.pdb -ox -n <<EOD
1
EOD

b=`tail -n1 coord.xvg |cut -f4`

z2=`bc -l <<< "scale=2; $z / 2 "`

out=`bc -l <<< "scale=2; $z2 - $b "`

martinize2 -f protein.pdb -x protein-cg.pdb -o protein-cg.top -elastic -ef 500 -eu 0.9 -el 0.5 -ea 0 -ep 0 -ff martini3001 -maxwarn -1 -ignh -merge A -dssp mkdssp

gmx editconf -f protein-cg.pdb -o protein-cg.gro 

#rm -r Repeat*
rm ./*txt
rm \#*

##Make repeats each with seperate insane builds##
for i in $(seq 1 $2)
do 

mkdir Repeat_$i
cd Repeat_$i

cp ../martini_v3.itp .

/path/to/python2 insane3.py -sol W -salt 0.15 -u PIMD:22 -u PIM6:11 -u PID6:10 -u TBPI:13 -u CARD:24 -u TBPE:20 -l PIMA:90 -l PIMD:10 -x $x -y $y -z $z -o CG-system.gro -p topol.top -f ../protein-cg.gro -dm $out -center -au 0.92 -a 1.13 -ring ### ALTER PATH HERE
sed -e 's/molecule_0/Protein/g' ../molecule_0.itp > protein-cg.itp

##Fix insane3 naming of ions##
sed -i 's/TNA/NA/g' CG-system.gro
sed -i 's/TNA/NA/g' topol.top 
sed -i 's/TCL/CL/g' CG-system.gro
sed -i 's/TCL/CL/g' topol.top

gmx make_ndx -f CG-system.gro -o sys.ndx << EOF
del 0-100
rW*
name 0 W
q
EOF

##Neutralise system##
gmx make_ndx -f CG-system.gro -o neutral.ndx <<EOD
del 0-50
rW
q
EOD

gmx grompp -f em.mdp -o neutral -c CG-system.gro  -maxwarn -1 
gmx genion -s neutral -p topol.top -neutral -o neutral.pdb -n neutral.ndx <<EOD
0
EOD

##EM##
gmx grompp -f em.mdp -o em -c neutral.pdb  -maxwarn -1

gmx mdrun -deffnm em -c CG-system.pdb -nt 1

gmx trjconv -f CG-system.pdb -o CG-system.pdb -pbc res -s em.tpr -conect <<EOD
0
EOD

gmx make_ndx -f CG-system.pdb -o sys.ndx << EOD
del 0
del 1-40
rTB*|rPOP*|rPIP*|rDHP*|rDPP*|rDMP*|rDOP*|rBOG*|rCHO*|rDDM*|rDSP*|rTOC*|rCAR*|rDLP*|rSQD*|rDGD*|rLMG*|rrMAG*|rLPA*|rUPP*|rCYST*|rCYSD*|rPAM*|rLIP*|rREM*|rRAM*|rCL1*|rDPS*|rAPG|rKPG|rPIM*|rTMM*|rPID*
r W | r ION
r BDQ
name 1 Lipid
name 2 SOL_ION
name 3 BDQ
q
EOD

mkdir MD

gmx grompp -f 10us-martini-2021.mdp -o MD/md -c CG-system.pdb  -maxwarn -1 -n sys.ndx

cd ..

done

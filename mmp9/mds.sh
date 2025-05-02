#!/bin/bash
set -euo pipefail

# Function to check if the previous command was successful
check_success() {
    if [ $? -ne 0 ]; then
        echo "\n❌ Error in step: $1"
        exit 1
    else
        echo "✅ Completed step: $1"
    fi
}

# Handle prefix input
if [ $# -ge 1 ]; then
    pref="$1"
else
    read -p "Enter the prefix for your system (e.g., RS08H0): " pref
fi

# Set MDP directory
mdp_dir="/data/mdp"      # Directory containing mdp files

# Load GROMACS
#source /usr/local/gromacs/bin/GMXRC
set +u
source /usr/local/gromacs/bin/GMXRC
set -u

# Detect total available cores
total_cores=$(nproc)
ntmpi=8
ntomp=$((total_cores / ntmpi))
echo ">>> Detected $total_cores cores: using $ntmpi MPI ranks and $ntomp OpenMP threads each"

# Step 1: pdb2gmx
echo ">>> Step 1: pdb2gmx"
echo -e "15\n1" | gmx pdb2gmx -f ${pref}_fixed.pdb -o ${pref}_processed.gro -ignh -water spce
check_success "pdb2gmx"

# Step 2: Define box
echo ">>> Step 2: Define Box"
gmx editconf -f ${pref}_processed.gro -o ${pref}_newbox.gro -box 10 10 10 -c -d 1.2 -bt cubic
check_success "editconf"

# Step 3: Solvate
echo ">>> Step 3: Solvate"
gmx solvate -cp ${pref}_newbox.gro -cs spc216.gro -o ${pref}_solv.gro -p topol.top
check_success "solvate"

# Step 4: Preprocess for ions
echo ">>> Step 4: grompp ions"
gmx grompp -f $mdp_dir/ions.mdp -c ${pref}_solv.gro -p topol.top -o ions.tpr -maxwarn 2
check_success "grompp ions"

# Step 5: Add ions
echo ">>> Step 5: genion"
echo "SOL" | gmx genion -s ions.tpr -o ${pref}_solv_ions.gro -p topol.top -pname NA -nname CL -neutral
check_success "genion"

# Step 6: Energy minimization
echo ">>> Step 6: EM grompp"
gmx grompp -f $mdp_dir/minim.mdp -c ${pref}_solv_ions.gro -p topol.top -o em.tpr
check_success "grompp em"

echo ">>> Step 6: EM run"
gmx mdrun -v -deffnm em -ntmpi $ntmpi -ntomp $ntomp
check_success "mdrun em"

# Step 7: NVT
echo ">>> Step 7: NVT grompp"
gmx grompp -f $mdp_dir/nvt.mdp -c em.gro -r em.gro -p topol.top -o nvt.tpr
check_success "grompp nvt"

echo ">>> Step 7: NVT run"
gmx mdrun -v -deffnm nvt -ntmpi $ntmpi -ntomp $ntomp
check_success "mdrun nvt"

# Step 8: NPT
echo ">>> Step 8: NPT grompp"
gmx grompp -f $mdp_dir/npt.mdp -c nvt.gro -r nvt.gro -t nvt.cpt -p topol.top -o npt.tpr
check_success "grompp npt"

echo ">>> Step 8: NPT run"
gmx mdrun -v -deffnm npt -ntmpi $ntmpi -ntomp $ntomp
check_success "mdrun npt"

# Step 9: Production run
echo ">>> Step 9: Production grompp"
gmx grompp -f $mdp_dir/md_0_100.mdp -c npt.gro -t npt.cpt -p topol.top -o ${pref}_0_100.tpr
check_success "grompp md"

echo ">>> Step 9: Production mdrun with checkpoint support"
gmx mdrun -noappend -deffnm ${pref}_0_100 -cpi ${pref}_0_100.cpt -ntmpi $ntmpi -ntomp $ntomp
check_success "mdrun production"

echo "\n simulation initiated succesfully!"

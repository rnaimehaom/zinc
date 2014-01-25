# Specify the beginning and ending slices
beg=0
end=126
# Download and unzip 16_*
curl -O http://zinc.docking.org/db/bysubset/16/16_prop.xls
curl -O http://zinc.docking.org/db/bysubset/16/16_purch.xls
for s in $(seq $beg $end); do
	curl -s http://zinc.docking.org/db/bysubset/16/16_p0.$s.mol2.gz | gunzip > 16_p0.$s.mol2
done
# Split mol2's that are not in 16_id.csv. File stems are 8 characters wide, without the ZINC prefix. This step requires 7 hours.
for s in $(seq $beg $end); do
	mkdir -p 16_p0.$s
done
../../utilities/filtermol2 ../2013-01-10/16_id.csv $beg $end
for s in $(seq $beg $end); do
	sort -c 16_p0.$s.csv
done
sort -m 16_p0.*.csv > 16_id_new.csv
# Convert mol2 to pdbqt. This step requires a few days.
mkdir -p pdbqt
cd mol2
for mol2 in *; do
	python2.5 ${MGLTOOLS_ROOT}/MGLToolsPckgs/AutoDockTools/Utilities24/prepare_ligand4.pyo -U '' -l $mol2 -o ../pdbqt/${mol2:0:8}.pdbqt
done
cd ..
# Update 16_lig.pdbqt. This step requires 3 hours.
../../utilities/updatepdbqt ../2013-01-10/16_id.csv 16_id_new.csv 16_prop.xls 16_purch.xls ../2013-01-10/16_lig.pdbqt pdbqt 16_id.csv 16_hdr.bin 16_prop.tsv 16_prop.bin 16_lig.pdbqt minmax.csv
# Verify
n=$(wc -l < 16_id.csv)
echo "ligands: $n"
if [[ $[8 * n] != $(wc -c < 16_hdr.bin) ]]; then
	echo "16_hdr.bin file size not matched"
fi
if [[ 0 != $(../../utilities/seekheaders 16_lig.pdbqt 16_hdr.bin | wc -l) ]]; then
	echo "seekheaders 16_lig.pdbqt 16_hdr.bin failed"
fi
if [[ $[1 + n] != $(wc -l < 16_prop.tsv) ]]; then
	echo "16_prop.tsv line size not matched"
fi
if [[ $[26 * n] != $(wc -c < 16_prop.bin) ]]; then
	echo "16_prop.bin file size not matched"
fi
#tail -n +2 16_prop.xls  | cut -f1 | cut -d'C' -f2 > 16_prop_id.tsv
#tail -n +2 16_purch.xls | cut -f1 | cut -d'C' -f2 > 16_purch_id.tsv
#../../utilities/removeduplicates 16_prop_id.tsv 16_prop_id_unique.tsv
#../../utilities/removeduplicates 16_purch_id.tsv 16_purch_id_unique.tsv
#../../utilities/overlaysubset 16_id_new.id 16_prop_id_unique.tsv
#../../utilities/overlaysubset 16_id_new.id 16_purch_id_unique.tsv
# Gzip 16_prop.bin for use in web.js
gzip 16_prop.bin
# Plot property distributions
Rscript prop.R
# Clean up
rm -rf *.mol2 mol2 pdbqt
# Deploy updated files
mv *.png ~/istar/public/idock
scp 16_prop.bin.gz pc89066:/home/hjli/istar/idock
scp 16_lig.pdbqt 16_hdr.bin proj74:/home/hjli/nfs/hjli/istar/idock
# Update minmax in web.js, public/idock/index.html, public/idock/index.js

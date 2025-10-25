#!/usr/bin/env bash
set -euo pipefail

IN="mapping/unmapped_reads"
OUTD="taxonomic"

mkdir -p "${OUTD}"

# Como los datos proviene de secuenciación de paired end, samtools ordena por nombre de lectura, no por coordenadas genómicas. 
# porque ´samtools fastq´ requiere pares R1/R2 contiguos para reconstruir las lecturas paireadas correctamente.
#samtools sort -n "${IN}/unmapped_evol1.bam" -o "${IN}/sorted_unmapped_evol1.bam"
#samtools sort -n "${IN}/unmapped_evol2.bam" -o "${IN}/sorted_unmapped_evol2.bam"
echo "Archivos .bam ordenados por nombre de lectura en ${IN}"
echo ""

#Borra los archivos basura
#rm -rf "${IN}/unmapped_evol1.bam" "${IN}/unmapped_evol2.bam" #Esta línea solo se descomenta una vez
#echo "Archivos no ordenados eliminados exitosamente"

#Convierte los BAM en FASTQ
#samtools fastq -1 "${OUTD}/unmapped_evol1_R1.fastq" -2 \
#"${OUTD}/unmapped_evol1_R2.fastq" "${IN}/sorted_unmapped_evol1.bam"

#samtools fastq -1 "${OUTD}/unmapped_evol2_R1.fastq" -2 \
#"${OUTD}/unmapped_evol2_R2.fastq" "${IN}/sorted_unmapped_evol2.bam"  
#echo "Archivos no mapeados .bam convertidos exitosamente a .fastq"
echo ""

#Descarga la base de datos de kraken2 reducida y la guarda en un directorio
mkdir -p db_kraken2

echo "Descargando base de datos de Kraken2..."
echo ""
#wget https://genome-idx.s3.amazonaws.com/kraken/k2_standard_16_GB_20250714.tar.gz
echo "Base de datos instalada..."
echo ""
#tar -xvzf k2_standard_16_GB_20250714.tar.gz -C db_kraken2
echo "Base de datos lista en db_kraken2/"
echo ""

#Actualiza la base de datos/actualiza el kronna
paths=$(find ~/ -name updateTaxonomy.sh )
for script in $paths; do
  echo ""
  echo "Running updateTaxonomy.sh at $script"
  bash "$script"
done

# Clasificación con Kronna
echo ""
echo "Iniciando clasificación taxonómica para muestra evol1..."
echo ""
kraken2 --db ./db_kraken2  --memory-mapping \
  --paired \
  --output taxonomic/kraken_output_evol1.txt \
  --report taxonomic/kraken_report_evol1.txt \
  taxonomic/unmapped_evol1_R1.fastq  taxonomic/unmapped_evol1_R2.fastq

ktImportTaxonomy -t 5 -m 3 -o "${OUTD}/krona_evolv1.html" "${OUTD}/kraken_report_evol1.txt"
echo "Krona evol1 lista en ${OUTD}/krona_evol1.html"
echo ""

echo ""
echo "Iniciando clasificación taxonómica para muestra evol2..."
echo ""
kraken2 --db ./db_kraken2  --memory-mapping \
  --paired \
  --output taxonomic/kraken_output_evol2.txt \
  --report taxonomic/kraken_report_evol2.txt \
  taxonomic/unmapped_evol2_R1.fastq  taxonomic/unmapped_evol2_R2.fastq

ktImportTaxonomy -t 5 -m 3 -o "${OUTD}/krona_evol2.html" "${OUTD}/kraken_report_evol2.txt"
echo "Krona evol2 lista en ${OUTD}/krona_evol2.html"
echo ""

echo ""
echo "Clasificación taxonómica completada exitosamente. Resultados de Krona guardados en '${OUTD}'"
echo ""
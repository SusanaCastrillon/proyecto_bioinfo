#!/usr/bin/env bash
set -euo pipefail

REF="assemble/filter_scaffold_anc_trimmed.fasta"
OUTD="VCF/"

# Verificar que existe el directorio de salida
mkdir -p "${OUTD}"

echo ""
echo "Anotando genoma de referencia con Prokka..."
echo ""
prokka --prefix anc_genome \
  --genus Escherichia \
  --species coli \
  --usegenus \
  --addgenes \
  --kingdom bacteria \
  --force \
  "${REF}" \
  --outdir "${OUTD}/anotation_anc"
# prefix es para que los archivos salgan con ese nombre
# genus, species, usegenus: le dice que busque información de E. coli
# addgenes: añade nombres de genes cuando sea posible
# kingdom: especifica que es bacteria
# force: sobrescribe si ya existe el directorio

echo ""
echo "Anotación Prokka completada"
echo ""
echo "Archivos generados en: ${OUTD}anotation_anc/"
echo "  - anc_genome.gff (anotación en formato GFF)"
echo "  - anc_genome.gbk (GenBank)"
echo "  - anc_genome.faa (proteínas)"
echo "  - anc_genome.ffn (genes)"

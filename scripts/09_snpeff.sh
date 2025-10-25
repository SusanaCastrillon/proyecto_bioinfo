#!/usr/bin/env bash
set -euo pipefail

REF="assemble/filter_scaffold_anc_trimmed.fasta"
OUTD="VCF/"
SAMPLES=("evol1" "evol2") # Array con los nombres de las muestras


# Verificar que existen los archivos necesarios
if [ ! -f "${OUTD}/anotation_anc/anc_genome.gff" ]; then
    echo "ERROR: No se encontró el archivo GFF de Prokka"
    echo "Ejecuta primero el script 09_prokka.sh"
    exit 1
fi

# Configurar SnpEff database (solo una vez)
echo "Configurando base de datos SnpEff..."
CONFIG_PATH=$(find ~ -name "snpEff.config" | head -n 1)

if [ -z "$CONFIG_PATH" ]; then
    echo "ERROR: No se encontró snpEff.config"
    echo "Verifica que SnpEff esté instalado correctamente"
    exit 1
fi

DB_ENTRY="anc_genome.genome : Simon_ecoli"
grep -qxF "$DB_ENTRY" "$CONFIG_PATH" || echo "$DB_ENTRY" >> "$CONFIG_PATH"

# Crear estructura de directorios para SnpEff
# Se crea una base de datos en snpeff para poder anotar las variantes
# para esto se tienen que cambiar documentos y valores internos del programa y colocar el
# GFF y los scaffolds en una carpeta con path relativo data/anc_genome
SNPEFF_DATA_DIR="$(dirname "$CONFIG_PATH")/data/anc_genome"
mkdir -p "$SNPEFF_DATA_DIR"

cp "${REF}" "${SNPEFF_DATA_DIR}/sequences.fa"
cp "${OUTD}/anotation_anc/anc_genome.gff" "${SNPEFF_DATA_DIR}/genes.gff"

# Construir base de datos SnpEff
echo "Construyendo base de datos SnpEff..."
JAR_PATH=$(find ~ -name "snpEff.jar" | head -n 1)

if [ -z "$JAR_PATH" ]; then
    echo "ERROR: No se encontró snpEff.jar"
    exit 1
fi

java -jar "$JAR_PATH" build -gff3 -v anc_genome

echo ""
echo "Base de datos SnpEff creada exitosamente"
echo ""

# Procesar cada muestra
for SAMPLE in "${SAMPLES[@]}"; do
    echo "-----------------------------------"
    echo "Procesando muestra ${SAMPLE}..."
    echo "-----------------------------------"
    
    # Verificar que existe el VCF
    if [ ! -f "${OUTD}/${SAMPLE}.vcf" ]; then
        echo "ERROR: No se encontró ${OUTD}/${SAMPLE}.vcf"
        echo "Ejecuta primero el script 08_variantcalling.sh"
        exit 1
    fi
    
    # Anotar variantes con SnpEff
    echo "  - Anotando variantes con SnpEff..."
    java -jar "$JAR_PATH" -v \
      -stats "${OUTD}/snpEff_stats_${SAMPLE}.html" \
      anc_genome \
      "${OUTD}/${SAMPLE}.vcf" \
      > "${OUTD}/annotated_${SAMPLE}.vcf"
    
    # Filtrar variantes con SnpSift
    echo "  - Filtrando variantes con SnpSift..."
    SNPSIFT_PATH=$(find ~ -name "SnpSift.jar" | head -n 1)
    
    if [ -z "$SNPSIFT_PATH" ]; then
        echo "ERROR: No se encontró SnpSift.jar"
        echo "Instala SnpSift con: conda install bioconda::snpsift"
        exit 1
    fi
    
    # Código para filtrar el VCF y quedarse con las variantes importantes
    # todo lo que tenga tags de downstream_gene_variant y upstream_gene_variant serán filtrados
    # porque el programa por default para dar este tag considera mutaciones
    # a mas de 5000 pb del inicio o final del gen y a esa distancia es muy poco probable encontrar
    # promotores o secuencias terminadoras
    # se están quitando las silent mutaciones (synonymous_variant)
    # las mutaciones en splice regions: E. coli no hace splicing
    # el --inverse es para que excluya esas entradas
    java -jar "$SNPSIFT_PATH" filter --inverse \
      "(ANN[*].EFFECT has 'downstream_gene_variant') || \
       (ANN[*].EFFECT has 'upstream_gene_variant') || \
       (ANN[*].EFFECT has 'synonymous_variant') || \
       (ANN[*].EFFECT has 'splice_region_variant')" \
      "${OUTD}/annotated_${SAMPLE}.vcf" \
      > "${OUTD}/filtered_annotated_${SAMPLE}.vcf"
    
    echo "  - Muestra ${SAMPLE} procesada exitosamente!"
    echo ""
done

echo "==================================="
echo "Pipeline SnpEff completado"
echo "==================================="
echo ""
echo "Archivos generados:"
for SAMPLE in "${SAMPLES[@]}"; do
    echo "  Muestra ${SAMPLE}:"
    echo "    - ${OUTD}annotated_${SAMPLE}.vcf"
    echo "    - ${OUTD}filtered_annotated_${SAMPLE}.vcf"
    echo "    - ${OUTD}snpEff_stats_${SAMPLE}.html"
done
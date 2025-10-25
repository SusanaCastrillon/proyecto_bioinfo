#!/usr/bin/env bash
set -euo pipefail

mkdir -p VCF

bcftools mpileup -Ou --redo-BAQ --fasta-ref --ploidy 1 assemble/filter_scaffold_anc_trimmed.fasta \
 --min-MQ 20  \
 mapping/filtered_aligned_trimmed_evol1.bam mapping/filtered_aligned_trimmed_evol2.bam \
 |bcftools call -mv -Ov | \
  bcftools filter -Ov --include 'QUAL>35 && DP>25' > VCF/evol1_evol2.vcf 
#el -min-Mq quita bases con calidad menor a 20
# el --Ou es para que salga en un formato adecuado para el pipeline --redo-BAQ disminuye falsos positivos
# -mv que use el metodo de defaul the llamado de variantes y "v" que solo incluya bases con variantes
# -Ov que el output sea vcf __iclude que solo tome en cuenta variantes con una
#profundidad mayor a 25 y una calidad mayor a 35 esta calidad es la calidad de la variante no de la base 

prokka  --prefix evol1_evol2 --genus Escherichia --species coli --usegenus --addgenes\
 --kingdom bacteria \
 assemble/filter_scaffold_anc_trimmed.fasta --outdir VCF/anotation_anc
# prefix es para que los archivos me salgan cpn ese nombre y el resto es
# diceindole que tiene que buscar e coli 

# Se crea una base de datos en snpeff para poder anotar las variantes 
# para esto se tienen que cambiar documentos y valores internos del programa y colocar el
# GFF y los scafolds en una carpeta con path relativo data/anc_genome

mv VCF/anotation_anc/evol1_evol2.gff VCF/anotation_anc/evol1_evol2_gff.gff
cd VCF/anotation_anc
mv evol1_evol2_gff.gff ..
cd ../..



CONFIG_PATH=$(find ~ -name "snpEff.config"  | head -n 1)
DB_ENTRY="anc_genome.genome : Simon_ecoli"

grep -qxF "$DB_ENTRY" "$CONFIG_PATH" || echo "$DB_ENTRY" >> "$CONFIG_PATH"

CONFIG_PATH=$(find ~ -name "snpEff.config"  | head -n 1)

mkdir -p "$(dirname "$CONFIG_PATH")/data/anc_genome"
cp assemble/filter_scaffold_anc_trimmed.fasta "$(dirname "$CONFIG_PATH")/data/anc_genome/sequences.fa"
cp VCF/evol1_evol2_gff.gff  "$(dirname "$CONFIG_PATH")/data/anc_genome/genes.gff"


JAR_PATH=$(find ~ -name "snpEff.jar"|head -n 1)

java -jar "$JAR_PATH" build -gff3 -v anc_genome

# codigo para anotar el vcf y producir un reporte de html
java -jar "$JAR_PATH" -v -stats VCF/snpEff_stats.html anc_genome VCF/evol1_evol2.vcf\
 > VCF/annotated_evol1_evol2.vcf

#conda install bioconda::snpsift  instalalo !!!!!!!###$######$$$!!!!!

#codigo para filtral el VCF y quedarse con las variables importantes 
# todo lo que tenga tags de downstream_gene_variant y upstream_gene_variant serna filtrados
#porque el programa por defaul para dar este tag considera mutaciones
# a mas de 5000 pb de el inicio o final del gen y a esa distancia es muy poco probable encontrar
# promotores o secuencias terminadoras
# se estan quitando las silent mutaciones 
#las mutaciones en splice regions ecoli no hace splicing 
# el inverse es para que excluya esas entradas 

SnpSift_PATH=$(find ~ -name "SnpSift.jar"|head -n 1)
java -jar "$SnpSift_PATH" filter --inverse \
"(ANN[*].EFFECT has 'downstream_gene_variant') || (ANN[*].EFFECT has 'upstream_gene_variant') || (ANN[*].EFFECT has 'synonymous_variant') || (ANN[*].EFFECT has 'splice_region_variant')" \
 VCF/annotated_evol1_evol2.vcf > VCF/filtered_annotated_evol1_evol2.vcf
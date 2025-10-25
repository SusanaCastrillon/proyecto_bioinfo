# Proyecto Genoma Bioinformática
En este proyecto analizaremos datos de secuenciación de _Escherichia coli_ obtenidos de un ensayo de evolución experimental. A partir de una población ancestral, las bacterias fueron sometidas a distintas condiciones de cultivo durante varias generaciones, lo que favorece la aparición de mutaciones que pueden conferir ventajas adaptativas y la comparación entre la población ancestral y las derivadas permite identificar los cambios genómicos responsables de esas adaptaciones. Para este análisis se simulará un flujo de trabajo, mostrado a continuación:


<img src="https://github.com/user-attachments/assets/7449d4cb-1cd1-41a3-949a-95f2c5e8944f" width="600" />


# **Pregunta Biológica**
¿Qué cambios genómicos surgen en _Escherichia coli_ bajo condiciones de cultivo controladas a lo largo de un experimento de evolución, y cómo estos cambios pueden estar relacionados con ventajas adaptativas en el fenotipo?

# 🗂 Estructura del repositorio
```
├── scripts/          # Scripts para la ejecución del análisis
├── quality_results/  # Reportes de calidad generados (FASTQC/MultiQC HTML)
│ ├── pre_qc/
│ ├── post_qc/
│ └── fastp/
├── assembly_results/ # scaffold.fasta + reporte QUAST
├── index/            # Archivos BAM procesados e indexados
├── VCF/              # Archivos VCF anotados y filtrados + reportes SnpEff
├── informe/          # Informe PDF con análisis biológico
└── README.md         # Este archivo
```

# 🚀 Ejecución del Flujo de trabajo 
Este repositorio contiene un conjunto de scripts bash que implementan un pipeline reproducible para analizar los datos de secuenciación en un contexto de evolución experimental, desde la estructura en los archivos inicial hasta el análisis de mapeo, para que este pipeline se pueda reproducir, es necesario cumplir con los siguientes prerrequisitos: 
1. Crear un environment con todos los paquetes y softwares, para eso es necesesario descargar el archivo `environment.yml` que se encuentra en la carpeta `scripts/` y correr el siguiente código en la terminal:

    `conda env create -f environment.yml`
3. Activar el entorno recien creado

   `conda activate project_env`
5. Activar los permisos de ejecución de los scripts

    `chmod +x scripts/*sh`
6. Ejecute cada srcipt en orden númerico. Ejemplo de código:

    `./ejemplo.sh` 

| Script           | Descripción                                                                        |
| ---------------- | ---------------------------------------------------------------------------------- |
| `setup.sh`    | Configura la estructura de carpetas, para mantener los reportes organizados        |
| `02_pre_qc.sh`       | Ejecuta **FastQC** y **MultiQC** sobre las lecturas crudas.                        |
| `03_trimming.sh` | Aplica **fastp** para trimming y filtrado por calidad.                             |
| `04_post_qc.sh` | Ejecuta **FastQC** y **MultiQC** sobre las lecturas depuradas por calidad.                            |
| `05_assemble_mapping.sh` | Ensamblaje de novo con **SPAdes** y evaluación con **Quast** y alineamiento de lecturas evolucionadas con **BWA** + procesamiento con `samtools`. |
| `06_variant_calling.sh` | Llamado de variantes con **bcftools** para identificar SNPs e indels entre el genoma ancestral y las líneas evolucionadas. |
| `07_prokka.sh` | Anotación funcional del genoma de referencia con **Prokka** para identificar genes, productos y funciones. |
| `08_snpeff.sh` | Anotación y predicción del impacto funcional de variantes con **SnpEff** y filtrado de variantes relevantes con **SnpSift**. |

# Explicación de códigos y flags importantes

## trimming_02

**fastp** comando que realiza el control de calidad para datos de secuenciación.

- `--detect_adapter_for_pe`  
  Detecta adaptadores con algoritmos específicos para *paired-end* (lecturas pareadas). Por defecto, esta detección automática está desactivada para datos *paired-end* y activarla puede mejorar la limpieza de las secuencias.

- `-qualified_quality_phred 28`  
  Elimina reads que tengan mas del 40 % de las bases por debajo de un valor phred de 28 

- `--length_required 80`  
  Retira cualquier lectura que tenga una longitud menor a 80 pares de bases (pb).

- `--cut_front --cut_tail --cut_mean_quality 28`  
  Corta bases al principio y al final de la secuencia ve la calidad promedio de las 4 primeras y ultimas bases si esta esta por debajo de un valor phred de 28 las corta y analisa las siguientes 4 bases si el valor phred esta por encima continua con el siguiente

## Assembly

**SPAdes** es un paquete que permite ensamblar genomas *de novo* o utilizando un genoma de referencia.

- `-1` indica el archivo con las lecturas de la hebra forward (forward strand).  
- `-2` indica el archivo con las lecturas de la hebra reverse (reverse strand).  
- `--isolate` es un flag recomendado para datos de Illumina; ajusta parámetros internos optimizados para lecturas Illumina y para ensamblajes de aislados bacterianos.

seqkit seq -m 100 scaffolds_anc_trimmed.fasta > filter_scaffold_anc_trimmed.fasta

Este comando elimina los scaffolds de menos de 100 pb, ya que:

- Scaffolds con menos de 100 bases no permiten identificar genes correctamente.
- Además, suelen ser más cortos que las lecturas que se mapearán sobre ellos.
- Los scaffolds filtrados (de longitud mayor o igual a 100) se guardan en un nuevo archivo FASTA (`filter_scaffold_anc_trimmed.fasta`).
  
## Mapping 

bwa index -p filter_scaffold_anc_raw ../filter_scaffold_anc_raw.fasta
Indexa o ordena los scaffolds para poder luego generar el archivo bam  
-p les pone al todos los archivos creados el nombre filter_scaffold_anc_raw 

 `bwa mem`  
  Ejecuta el algoritmo BWA-MEM que crea el archivo SAM 

- `assemble/extra_info/filter_scaffold_anc_trimmed`  
  Prefijo de los archivos índice del genoma de referencia (los archivos generados previamente con `bwa index`).

- `data/trimmed_data/evol1_R1.trimmed.fastq`  
  Archivo FASTQ con las lecturas de la hebra forward 

- `data/trimmed_data/evol1_R2.trimmed.fastq`  
  Archivo FASTQ con las lecturas de la hebra reverse 

**Samtools** 

samtools view -b -F 4 -q 30 mapping/aligned_raw_evol1.sam | \
samtools sort -n -o mapping/trash.bam -

samtools fixmate -m mapping/trash.bam \
mapping/trash.fixmate.bam

samtools sort -o - mapping/trash.fixmate.bam | \
samtools markdup -r - mapping/filtered_aligned_raw_evol1.bam
rm -rf mapping/trash* 


- `-b`  
  Genera la salida en formato BAM (binario), más eficiente para procesamiento.

- `-F 4`  
  Excluye las lecturas con el flag 4, que indica lecturas **no mapeadas**.

- `-q 30`  
  Excluye lecturas con calidad de mapeo menor a 30.

- Combinación de `sort -n` y `fixmate`:  
  Ordena las lecturas por nombre para asegurar que pares estén juntos y corrige información del par, preparando los datos para la eliminación de duplicados.

- `markdup -r`  
  Marca y remueve lecturas duplicadas.

- `rm -rf mapping/trash*`  
  Elimina archivos temporales generados en el proceso.

  ## Variant Calling (06_VCF.sh)

**bcftools mpileup + call:**
```bash
bcftools mpileup -Ou --redo-BAQ --fasta-ref assemble/filter_scaffold_anc_trimmed.fasta \
  --ploidy 1 --min-MQ 20 \
  mapping/filtered_aligned_trimmed_evol1.bam mapping/filtered_aligned_trimmed_evol2.bam \
  | bcftools call -mv -Ov \
  | bcftools filter -Ov --include 'QUAL>35 && DP>25' > VCF/evol1_evol2.vcf
```
- `--redo-BAQ`: Recalcula la calidad de bases para disminuir falsos positivos causados por errores de alineamiento cerca de indels.
- `--min-MQ 20`: Filtra bases con calidad de mapeo menor a 20.
- `--ploidy 1`: Especifica que el genoma es haploide (bacterias).
- `-Ou`: Salida en formato binario no comprimido, optimizado para pipelines.
- `-mv`: Usa el método de llamado de variantes multialélico (`m`) y solo incluye sitios variantes (`v`).
- `-Ov`: Salida en formato VCF estándar (texto).
- `--include 'QUAL>35 && DP>25'`: Retiene solo variantes con calidad > 35 y profundidad de cobertura > 25x, asegurando alta confiabilidad.

**Nota:** La calidad (`QUAL`) se refiere a la confianza estadística de la variante, no a la calidad de la base.

## Anotación Funcional con Prokka (07_prokka.sh )

**Prokka** anota genomas bacterianos prediciendo genes, tRNAs, rRNAs y asignando funciones basadas en bases de datos.
```bash
prokka --prefix anc_genome \
  --genus Escherichia \
  --species coli \
  --usegenus \
  --addgenes \
  --kingdom bacteria \
  --force \
  assemble/filter_scaffold_anc_trimmed.fasta \
  --outdir VCF/anotation_anc

- `--prefix anc_genome`: Nombre base para todos los archivos de salida.
- `--genus Escherichia --species coli`: Especifica el organismo para búsquedas en bases de datos específicas.
- `--usegenus`: Usa bases de datos específicas del género para mejorar anotación.
- `--addgenes`: Añade nombres de genes cuando sea posible.
- `--kingdom bacteria`: Especifica que es un genoma bacteriano.
- `--force`: Sobrescribe el directorio de salida si ya existe.

## Anotación y Filtrado de Variantes con SnpEff (08_snpeff.sh)

### Configuración de Base de Datos SnpEff

**SnpEff** requiere una base de datos personalizada del genoma de referencia para anotar el impacto funcional de las variantes.

**Pasos de configuración:**

1. **Editar `snpEff.config`**: Se añade una entrada para el genoma personalizado.
```bash
DB_ENTRY="anc_genome.genome : Simon_ecoli"
grep -qxF "$DB_ENTRY" "$CONFIG_PATH" || echo "$DB_ENTRY" >> "$CONFIG_PATH"
```

2. **Crear estructura de directorios**: SnpEff requiere que los archivos estén en `data/anc_genome/`.
```bash
mkdir -p "$(dirname "$CONFIG_PATH")/data/anc_genome"
cp assemble/filter_scaffold_anc_trimmed.fasta "$(dirname "$CONFIG_PATH")/data/anc_genome/sequences.fa"
cp VCF/anotation_anc/anc_genome.gff "$(dirname "$CONFIG_PATH")/data/anc_genome/genes.gff"
```

3. **Construir la base de datos**:
```bash
java -jar "$JAR_PATH" build -gff3 -v anc_genome
```

- `-gff3`: Indica que el archivo de anotación está en formato GFF3.
- `-v`: Modo verbose (muestra detalles del proceso).

### Anotación de Variantes
```bash
java -jar "$JAR_PATH" -v \
  -stats VCF/snpEff_stats_evol1.html \
  anc_genome \
  VCF/evol1.vcf \
  > VCF/annotated_evol1.vcf
```

- `-stats`: Genera un reporte HTML con estadísticas de las variantes anotadas (distribución por tipo, impacto, genes afectados).
- `anc_genome`: Nombre de la base de datos personalizada creada.
- Salida: VCF anotado con información en el campo `ANN` (efecto, gen, cambio aminoacídico, impacto).

**Clasificación de impacto de SnpEff:**
- **HIGH**: Pérdida o ganancia de función (frameshifts, stop gained/lost, start lost).
- **MODERATE**: Cambios no-sinónimos (missense).
- **LOW**: Cambios sinónimos.
- **MODIFIER**: Variantes intergénicas o intrón.

### Filtrado con SnpSift

**SnpSift** filtra variantes según criterios específicos del campo `ANN`.
```bash
java -jar "$SNPSIFT_PATH" filter --inverse \
  "(ANN[*].EFFECT has 'downstream_gene_variant') || \
   (ANN[*].EFFECT has 'upstream_gene_variant') || \
   (ANN[*].EFFECT has 'synonymous_variant') || \
   (ANN[*].EFFECT has 'splice_region_variant')" \
  VCF/annotated_evol1.vcf \
  > VCF/filtered_annotated_evol1.vcf
```

**Criterios de filtrado aplicados:**

- `--inverse`: Excluye (en lugar de incluir) las variantes que cumplan los criterios.

**Variantes excluidas:**
1. **downstream_gene_variant**: Variantes > 5000 pb después del final del gen (poco probable que afecten función).
2. **upstream_gene_variant**: Variantes > 5000 pb antes del inicio del gen.
3. **synonymous_variant**: Mutaciones silenciosas que no cambian el aminoácido.
4. **splice_region_variant**: Variantes en regiones de splicing (no aplica a E. coli, que no hace splicing).

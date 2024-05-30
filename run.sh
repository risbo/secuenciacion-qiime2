#!/bin/bash



# wget https://data.qiime2.org/distro/amplicon/qiime2-amplicon-2024.2-py38-linux-conda.yml
# conda env create -n qiime2-amplicon-2024.2 --file qiime2-amplicon-2024.2-py38-linux-conda.yml

mkdir qiime2-atacama-tutorial 
cd qiime2-atacama-tutorial
wget -O "sample-metadata.tsv" https://data.qiime2.org/2023.5/tutorials/atacama-soils/sample_metadata.tsv

mkdir emp-paired-end-sequences

wget -O "emp-paired-end-sequences/forward.fastq.gz" "https://data.qiime2.org/2023.5/tutorials/atacama-soils/10p/forward.fastq.gz"
wget -O "emp-paired-end-sequences/reverse.fastq.gz" "https://data.qiime2.org/2023.5/tutorials/atacama-soils/10p/reverse.fastq.gz"
wget -O "emp-paired-end-sequences/barcodes.fastq.gz" "https://data.qiime2.org/2023.5/tutorials/atacama-soils/10p/barcodes.fastq.gz"

ls


# conda activate qiime2-amplicon-2024.2

qiime tools import --type EMPPairedEndSequences --input-path emp-paired-end-sequences --output-path emp-paired-end-sequences.qza

ls emp-paired-end-sequences

# 3. Demultiplex reads:

qiime demux emp-paired --m-barcodes-file sample-metadata.tsv --m-barcodes-column barcode-sequence --p-rev-comp-mapping-barcodes --i-seqs emp-paired-end-sequences.qza --o-per-sample-sequences demux-full.qza --o-error-correction-details demux-details.qza
ls

# 4. Crear una submuestra:

qiime demux subsample-paired --i-sequences demux-full.qza --p-fraction 0.3 --o-subsampled-sequences demux-subsample.qza
qiime demux summarize --i-data demux-subsample.qza --o-visualization demux-subsample.qzv
ls

# 5. Filtrar muestras que tienen menos de 100 reads:
qiime tools export --input-path demux-subsample.qzv --output-path ./demux-subsample/
qiime demux filter-samples --i-demux demux-subsample.qza --m-metadata-file ./demux-subsample/per-sample-fastq-counts.tsv --p-where 'CAST([forward sequence count] AS INT) > 100' --o-filtered-demux demux.qza

# 6. Revisar calidad y realizar “denoising”:
qiime dada2 denoise-paired --i-demultiplexed-seqs demux.qza --p-trim-left-f 13 --p-trim-left-r 13 --p-trunc-len-f 150 --p-trunc-len-r 150 --o-table table.qza --o-representative-sequences rep-seqs.qza --o-denoising-stats denoising-stats.qza
# generar resumenes
qiime feature-table summarize --i-table table.qza --o-visualization table.qzv --m-sample-metadata-file sample-metadata.tsv
qiime feature-table tabulate-seqs --i-data rep-seqs.qza --o-visualization rep-seqs.qzv
qiime metadata tabulate --m-input-file denoising-stats.qza --o-visualization denoising-stats.qzv

#7. Generar un árbol para el análisis de diversidad filogenética:
qiime phylogeny align-to-tree-mafft-fasttree --i-sequences rep-seqs.qza --o-alignment aligned-rep-seqs.qza --o-masked-alignment masked-aligned-rep-seqs.qza --o-tree unrooted-tree.qza --o-rooted-tree rooted-tree.qza

# 8. Cálculo de diversidad alfa y beta:
# Rarefacción y cálculo de diversidad (reemplaza el número que sigue a “p-sampling-depth” con el que tú has seleccionado):
qiime diversity core-metrics-phylogenetic --i-phylogeny rooted-tree.qza --i-table table.qza --p-sampling-depth 1001 --m-metadata-file sample-metadata.tsv --output-dir core-metrics-results
qiime diversity alpha-group-significance --i-alpha-diversity core-metrics-results/shannon_vector.qza --m-metadata-file sample-metadata.tsv --o-visualization core-metrics-results/shannon_vector-group-significance.qzv
# Análisis PERMANOVA de diversidad beta: 
qiime diversity beta-group-significance --i-distance-matrix core-metrics-results/jaccard_distance_matrix.qza --m-metadata-file sample-metadata.tsv --m-metadata-column vegetation --o-visualization core-metrics-results/jaccard-vegetation-significance.qzv --p-pairwise
# Gráfico PCoA:
qiime emperor plot --i-pcoa core-metrics-results/bray_curtis_pcoa_results.qza --m-metadata-file sample-metadata.tsv --p-custom-axes elevation --o-visualization core-metrics-results/bray_curtis-emperor-elevation.qzv

# 9. Análisis taxonómico:
wget -O "gg-13-8-99-515-806-nb-classifier.qza" "https://data.qiime2.org/2023.5/common/gg-13-8-99-515-806-nb-classifier.qza"
qiime feature-classifier classify-sklearn --i-classifier gg-13-8-99-515-806-nb-classifier.qza --i-reads rep-seqs.qza --o-classification taxonomy.qza
qiime metadata tabulate --m-input-file taxonomy.qza --o-visualization taxonomy.qzv


#10. Análisis diferencial de abundancia microbiana:
qiime composition add-pseudocount --i-table table.qza --o-composition-table comp-table.qza
#Correr AMCO (para análisis diferencial):
qiime composition ancom --i-table comp-table.qza --m-metadata-file sample-metadata.tsv --m-metadata-column extract-group-no --o-visualization ancom-extract-group-no.qzv
#Agregar taxonomía:
qiime taxa collapse --i-table table.qza --i-taxonomy taxonomy.qza --p-level 7 --o-collapsed-table table-l7.qza
qiime composition add-pseudocount --i-table table-l7.qza --o-composition-table comp-table-l7.qza
qiime composition ancom --i-table comp-table-l7.qza --m-metadata-file sample-metadata.tsv --m-metadata-column transect-name --o-visualization l7-ancom-transect-name.qzv


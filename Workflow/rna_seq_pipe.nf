
nextflow.enable.dsl=2





process buildIndex {
	publishDir "${params.outputdir}/staridx_output", mode: 'copy'
	
	input:
	path fasta 
	path gtf 
	path vcf 
	
	output: 
	path "ref_data" 
	
	
	"""
	
	
	mkdir ref_data
	chmod +rwx ref_data
	 
	gunzip -c $fasta > /tmp/ref.fa
	
	
	
	gunzip -c $gtf >/tmp/ref.gtf
	
	
	##create an  samtools index
	samtools faidx /tmp/ref.fa
	
	
	##create a dict 
	java -jar $params.picard CreateSequenceDictionary R= /tmp/ref.fa O= ref.dict
	
	##unzip the vcf file 
	gunzip -c $vcf > ${vcf.baseName}
	
	
	##indexinf the vcf file 
	java -jar $params.gatk IndexFeatureFile -I ${vcf.baseName}
	
	STAR --runThreadN $task.cpus --runMode genomeGenerate\
	--genomeDir ref_data --genomeFastaFiles /tmp/ref.fa  --sjdbOverhang 100 --sjdbGTFfile /tmp/ref.gtf  --genomeSAindexNbases 11
	
	mv /tmp/ref.gtf ref_data/ref.gtf
	mv /tmp/ref.fa.fai ref_data/ref.fa.fai
	mv ref.dict ref_data/ref.dict
	mv ${vcf.baseName} ref_data/${vcf.baseName}
	mv ${vcf.baseName}.idx ref_data/${vcf.baseName}.idx
	mv /tmp/ref.fa ref_data/ref.fa
	
	"""
}



process doSTAR {
	
	input :
	
	
	path index 
	tuple val(sample), file(fqFile)
	

	
	output: 
	path "${sample}StarOutAligned.sortedByCoord.out.bam" 
	path "*StarOutLog.final.out" 
	path "*_fastqc.{zip,html}" 
	
	"""

	fastqc -t 8 -q $fqFile
	gunzip -c $fqFile|\
	STAR --genomeDir $index \
	--readFilesIn $fqFile\
	--readFilesCommand gunzip -c \
	--outFileNamePrefix $sample'StarOut' \
	--runThreadN $task.cpus \
	--sjdbGTFfile $index/ref.gtf\
	--twopassMode None --outFilterType BySJout  --seedSearchStartLmax 12 \
	--alignEndsType Local --outSAMtype BAM SortedByCoordinate \
	--alignIntronMax 1000000 \
	--alignMatesGapMax 1000000 \
	--limitOutSJcollapsed 1000000 \
	--limitSjdbInsertNsj 1000000 \
	--outFilterMultimapNmax 100 --winAnchorMultimapNmax 50 \
	--alignSJoverhangMin 15 \
	--alignSJDBoverhangMin 1 \
	--alignIntronMin 20 \
	--outFilterMatchNminOverLread 0 \
	--outFilterScoreMinOverLread 0.3 \
	--outFilterMismatchNmax 33 \
	--outFilterMismatchNoverLmax 0.33 
	
	
	"""

	
}

process FCounts {
	publishDir "${params.outputdir}/FC_output", mode: 'copy'

	input:
	file allbams 
	path index2 

	
	
	output: 
	path "exonscount.summary" 
	path "genecount.summary" 
	path "genecount"
	path "exonscount" 
	path"genecount_matrix.tab"
	
	
	""" 
	
	featureCounts -T $task.cpus  -a $index2/ref.gtf -o exonscount -p -s 2 -f -t exon -g exon_id  $allbams
	featureCounts -t 'exon' -g 'gene_id' -a $index2/ref.gtf -T $task.cpus -o genecount $allbams
	awk 'NR>1' genecount >genecount.tab
	(head -n 1 genecount.tab && tail -n +2 genecount.tab | sort -d)>genecount1.tab
	sort -d $index2/geneInfo.tab > geneinfos.tab
	awk 'NR>1' geneinfos.tab>geneinfos1.tab
	awk 'BEGIN { print "Geneid\tGenename\tGenetype" } { print }' geneinfos1.tab > geneinfos2.tab
	paste geneinfos2.tab  genecount1.tab  > genecount_matrix.tab
	
	"""
}

process multiqc {
	publishDir "${params.outputdir}/MULTIqc_output", mode: 'copy'
    input:
   
	path 'fastqc/*'
	path logstar
    output:
    file "*.html"
    path "multiqc_data"

    script:
    """
    multiqc .
    """
}
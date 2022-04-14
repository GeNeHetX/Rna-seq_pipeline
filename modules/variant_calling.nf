nextflow.enable.dsl=2

Channel.fromList(file(params.sampleList).readLines())
.map {
  [it ,  file(params.sampleInputDir + "/" + it + params.samPsuffix1),file(params.sampleInputDir + "/" + it + params.samPsuffix2)] }
.set { samples_ch }




process PicardSamsorted{
	

	input :
	file bamfile 
	output:
	file "*_sorted.bam" 
	
	"""
	##marking duplicates 
	java -XX:ParallelGCThreads= $task.cpus -jar $params.picard  MarkDuplicates \
		I= $bamfile\
      		O=${bamfile.baseName}marked_duplicates.bam \
      		M=${bamfile.baseName}marked_dup_metrics.txt && \
      	java -XX:ParallelGCThreads= $task.cpus -jar $params.picard SortSam \
      		I=${bamfile.baseName}marked_duplicates.bam\
      		O=${bamfile.baseName}marked_duplicates_sorted.bam \
      		SORT_ORDER=coordinate
	
	
	  
	"""



}




process gatk_vc {
	publishDir "${params.outputdir}/VCF_output", mode: 'copy'
	input :
	path ref_data
	file sortedbam   
	
	
	output: 
	file "{sortedbam.baseName}.vcf" 
	
	
	"""
	
 
	##SplitNCigar 
	java -jar $params.gatk SplitNCigarReads \
		--native-pair-hmm-threads $task.cpus\
      		-R $ref_data/ref.fa\
      		-I $sortedbam\
      		-O ${sortedbam.baseName}_split.bam 
	##adding groups to reads 
	java -XX:ParallelGCThreads= $task.cpus -jar $params.picard AddOrReplaceReadGroups \
		I= ${sortedbam.baseName}_split.bam \
		O= ${sortedbam.baseName}_split_RG.bam\
		RGID=1 \
		RGLB=lib2 \
		RGPL=illumina \
		RGPU=unit1 \
		RGSM=3 
	
	##BaseRecalibrator 
	java -jar $params.gatk BaseRecalibrator \
	  	--native-pair-hmm-threads $task.cpus\
	  	-I ${sortedbam.baseName}_split_RG.bam\
	  	-R $ref_data/ref.fa  \
	  	--known-sites $ref_data/knowns_variants.vcf \
	  	--use-jdk-inflater true \
	  	--use-jdk-deflater true \
	  	-O ${sortedbam.baseName}_split_RG_recal_data.table
	##ApplyBQSR
	java -jar $params.gatk ApplyBQSR \
		--native-pair-hmm-threads $task.cpus\
		-R $ref_data/ref.fa \
		-I ${sortedbam.baseName}_split_RG.bam \
		--bqsr-recal-file ${sortedbam.baseName}_split_RG_recal_data.table\
		-O ${sortedbam.baseName}_abqsr.bam
	##Running HaplotypeCaller 
	java -jar $params.gatk HaplotypeCaller --native-pair-hmm-threads $task.cpus \
		 -R $ref_data/ref.fa \
		 -I ${sortedbam.baseName}_abqsr.bam \
		 -O ${sortedbam.baseName}.vcf -bamout ${sortedbam.baseName}_out.bam



	"""
}


process Vep{

	publishDir "${params.outputdir}/VEP_output", mode: 'copy'
	
	input: 
	path vcf 
	
	output: 
	path "*.txt"
	
	script: 
	"""
	./vep -i $vcf -o ${vcf.baseName}.txt \
	 -offline\
	 -cache \
	 --variant_class \
	 --sift\
	 --polyphen \
	 --humdiv\
	 --nearest \
	 --distance\
	 --overlaps\
	 --gene_phenotype\
	 --regulatory\
	 --mirna\
	 --hgvs\
	 --protein
	 
	 


	"""
}

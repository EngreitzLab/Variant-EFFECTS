## Run CRISPResso for each FASTQ file


rule run_crispresso:
	input:
		read1=lambda wildcards: samplesheet.at[wildcards.SampleID,'fastqR1'],
		read2=lambda wildcards: samplesheet.at[wildcards.SampleID,'fastqR2']
	output:
		'crispresso/CRISPResso_on_{SampleID}/'
		#'crispresso/CRISPResso_on_{SampleID}/{AmpliconID}.Alleles_frequency_table_around_sgRNA_{GuideSpacer}.txt'
	params:
		amplicon_id=lambda wildcards: samplesheet.at[wildcards.SampleID,'AmpliconID'],
		amplicon_seq=lambda wildcards: samplesheet.at[wildcards.SampleID,'AmpliconSeq'],
		guide=lambda wildcards: samplesheet.at[wildcards.SampleID,'GuideSpacer'],
		q=config['crispresso_min_average_read_quality'],
		s=config['crispresso_min_single_bp_quality']
	#conda:
	#    "envs/CRISPResso.yml"  
	## 4/14/21 JE - Specifying the conda environment here is not working, and I am not sure why. Snakemake builds the conda environment, but then the conda environment doesn't work properly (CRISPResso not on the path)
	#   (This was on Sherlock, running snakemake from EngreitzLab conda envrionment).
	#  So, instead used the syntax below to activate the already installed conda env
	shell:
		"""
		bash -c '
			. $HOME/.bashrc 
			conda activate crispresso2_env
			CRISPResso \
				-r1 {input.read1} \
				-r2 {input.read2} \
				-o results/crispresso/ \
				--amplicon_seq {params.amplicon_seq} \
				--amplicon_name {params.amplicon_id} \
				--name {wildcards.SampleID} \
				--guide_seq {params.guide} \
				-q {params.q} -s {params.s} || true'
		"""

# Ben's version also includes CRISPResso params:  --cleavage_offset -14 --offset_around_cut_to_plot 10 
# To do: consider adding 				--max_paired_end_reads_overlap for FLASH overlap (calculate from read lengths, and length of amplicon)
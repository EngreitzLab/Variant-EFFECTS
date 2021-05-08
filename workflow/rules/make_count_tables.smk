## Create a count table from crispresso output that looks like:
## MappingSequence  A   B   C   D  ... other bin names

import os
import pandas as pd
import numpy as np


def make_count_table(samplesheet, group_col, group_id, bins, outfile, outfile_frequencies):
    ## Function to make a count table at various layers of resolution (e.g., by experiment, or by replicate, or by PCR replicate)
    ## To do: Move the python code for these rules into separate python scripts so they can be run independently of the snakemake pipeline (at least, this makes it easier to test and debug the code)

    currSamples = samplesheet.loc[samplesheet[group_col]==group_id]

    allele_tbls = []

    for idx, row in currSamples.iterrows():
        file = "results/crispresso/CRISPResso_on_{SampleID}/{AmpliconID}.Alleles_frequency_table_around_sgRNA_{GuideSpacer}.txt".format(
            SampleID=row['SampleID'], 
            AmpliconID=row['AmpliconID'], 
            GuideSpacer=row['GuideSpacer'])

        if (os.path.exists(file)):
            allele_tbl = pd.read_table(file)
            allele_tbl['#Reads'] = allele_tbl['#Reads'].astype(np.int32)
            ref_seq = allele_tbl.loc[allele_tbl['Aligned_Sequence'] == allele_tbl['Reference_Sequence'], 'Reference_Sequence'].values[0]
            allele_tbl = allele_tbl.loc[allele_tbl['Reference_Sequence'] == ref_seq] # necessary?
            allele_tbl = allele_tbl[['Aligned_Sequence', '#Reads']]
            allele_tbl.columns = ['Aligned_Sequence', row['SampleID']]
            allele_tbls.append(allele_tbl)

    if len(allele_tbls) > 0:
        count_tbl = allele_tbls.pop()

        for tbl in allele_tbls:
            count_tbl = count_tbl.merge(tbl, on='Aligned_Sequence', how='outer')

        count_tbl = count_tbl.set_index('Aligned_Sequence')
        count_tbl = count_tbl.fillna(0)
        count_tbl = count_tbl.astype(int)

        ## Now, sum counts per bin
        bin_list = bins + list(set(currSamples['Bin'].unique())-set(bins))
        for uniqBin in bin_list:
            samples = currSamples.loc[currSamples['Bin'] == uniqBin]
            if len(samples) > 0:
                count_tbl[uniqBin] = count_tbl[samples['SampleID']].sum(axis=1).values
                
            else:
                count_tbl[uniqBin] = 0
        count_tbl = count_tbl[bin_list]

    else:
        count_tbl = pd.DataFrame({'Aligned_Sequence':[]})
        for uniqBin in bins:
            count_tbl[uniqBin] = []
        count_tbl = count_tbl.set_index('Aligned_Sequence')

    count_tbl.index.name = "MappingSequence"
    count_tbl.to_csv(outfile, sep='\t')

    freq_tbl = count_tbl.div(count_tbl.sum(axis=0), axis=1)
    freq_tbl.to_csv(outfile_frequencies, sep='\t', float_format='%.6f')



def make_flat_table(samplesheet, outfile):

    allele_tbls = []
    for idx, row in samplesheet.iterrows():
        file = "{CRISPRessoDir}/{AmpliconID}.Alleles_frequency_table_around_sgRNA_{GuideSpacer}.txt".format(
            CRISPRessoDir=row['CRISPRessoDir'],
            AmpliconID=row['AmpliconID'],
            GuideSpacer=row['GuideSpacer'])

        if (os.path.exists(file)):
            allele_tbl = pd.read_table(file)
            allele_tbl['SampleID'] = row['SampleID']
            allele_tbls.append(allele_tbl)

    flat = pd.concat(allele_tbls, axis='index', ignore_index=True)
    flat.to_csv(outfile, sep='\t', index=False, compression='gzip')



rule make_count_table_per_PCRrep:
    input: 
        lambda wildcards: 
            samplesheet.loc[samplesheet['ExperimentIDPCRRep']==wildcards.ExperimentIDPCRRep]['CRISPRessoDir']
    output:
        counts='results/byPCRRep/{ExperimentIDPCRRep}.bin_counts.txt',
        freq='results/byPCRRep/{ExperimentIDPCRRep}.bin_freq.txt'
    run:
        make_count_table(samplesheet, 'ExperimentIDPCRRep', wildcards.ExperimentIDPCRRep, get_bin_list(), output.counts, output.freq)



rule make_count_table_per_experimentalRep:
    input: 
        lambda wildcards: 
            samplesheet.loc[samplesheet['ExperimentIDReplicates']==wildcards.ExperimentIDReplicates]['CRISPRessoDir']
    output:
        counts='results/byExperimentRep/{ExperimentIDReplicates}.bin_counts.txt',
        freq='results/byExperimentRep/{ExperimentIDReplicates}.bin_freq.txt'
    run:
        make_count_table(samplesheet, 'ExperimentIDReplicates', wildcards.ExperimentIDReplicates, get_bin_list(), output.counts, output.freq)



rule make_flat_count_table_PCRrep:
    input: 
        lambda wildcards: samplesheet['CRISPRessoDir']
    output:
        'results/summary/VariantCounts.flat.tsv.gz',
    run:
        make_flat_table(samplesheet, output[0])

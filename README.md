# bacpipe
A pipeline for simple and efficient processing of bacterial RNA-seq.
<img align="right" width="281" height="330" src="https://www.soulseeds.com/wp-content/uploads/2013/10/bagpipes-joke.jpg">

## Author
[Alexander Predeus](https://www.researchgate.net/profile/Alexander_Predeus), [Jay Hinton Laboratory](http://www.hintonlab.com/), [University of Liverpool](https://www.liverpool.ac.uk/)

(c) 2018, GPL v3 license

## Motivation
RNA-seq processing includes multiple steps, with best practices often varying between different species and laboratories. This pipeline deals with quality control, alignment, visualization, and quantification of bacterial RNA-seq experiments. 

When successfully applied, this should generate:
* genomic bam files for read-resolution visualization and analysis;
* tdf files for visualization in IGV;
* scaled bigWig files for visualization in JBrowse (see [doi:10.1128/mBio.01442-14](http://mbio.asm.org/content/5/4/e01442-14.full) for description of scaling); 
* three expression tables - from [featureCounts](http://subread.sourceforge.net/), [rsem](https://deweylab.github.io/RSEM/), and [kallisto](https://pachterlab.github.io/kallisto/); 
* a single [MultiQC](http://multiqc.info/) quality control report.

## Installation and requirements 
Clone the pipeline scripts into your home directory and add them to $PATH variable in bash: 

```bash
cd ~
git clone https://github.com/apredeus/bacpipe
echo "export ~/bacpipe:$PATH" >> .bashrc
```

To install the requirements, use [Bioconda](https://bioconda.github.io/). These are the programs that need to be installed: 

```bash
conda install fastqc
conda install bowtie2
conda install samtools
conda install bedtools
conda install picard
conda install igvtools
conda install rsem
conda install kallisto
conda install subread
```

You also need to have Perl installed. Sorry. 

## Reference preparation
In order to start using the pipeline, you would need two things: a genomic *fasta* file, and genome annotation in *gff3* format. You can also use Prokka-style *gff3* file that has both annotation and sequence. The reference preparation script will try and guess which one are you using. 

It is very much recommended to develop a system of "tags" that you would use to identify references; for example, if you are processing data for P125109 strain of Salmonella enterica, and intend to use the assembly and annotation available from NCBI, rename the downloaded files to **P125109_ncbi.fa** and **P125109_ncbi.gff3**. After you set the reference directory, and run the reference-maker script, all of the reference indexes etc would be appropriately named and placed. For example, rsem reference would be in $REFDIR/rsem/P125109_ncbi_rsem, bowtie2 reference in $REFDIR/bowtie2/P125109_ncbi.\*.bt2, and so on. 

After you have procured the *fasta* and the *gff3* and selected a (writeable) reference directory, simply run 

`prepare_bacpipe_reference.sh <reference dir> <tag> <name>.gff3 <name>.fa`

## One-command RNA-seq processing
After all the references are successfully created, simply run 

`run_bacpipe.sh <reference_dir> <tag> <CPUs>`

Bacpipe needs to be ran in a writeable directory with fastqs folder in it. 

Bacpipe:
* handles archived (.gz) and non-archived fastq files; 
* handles single-end and paired-end reads; 
* automatically detects strand-specificity of the experiment; 
* performs quantification according to the calculated parameters. 

The following steps are performed during the pipeline execution: 
* FastQC is ran on all of the fastq files; 
* bowtie2 is used to align the fastq files to the rRNA and tRNA reference to accurately estimate rRNA/tRNA content; 
* bowtie2 is used to align the fastq files to the genomic reference using --very-sensitive-local mode;
* sam alignments are filtered by quality (q10), sorted, converted to bam, and indexed; 
* tdf files are prepared for visualization in IGV; 
* bigWig (bw) files are prepared for vizualization in majority of other genomic browsers; 
* featureCounts is ran on genomic bam to evaluate the strandedness of the experiment; 
* strandedness and basic alignment statistics are calculated; 
* featureCounts output is chosen based correct settings of strandedness; 
* rsem is ran for EM-based quantification; 
* kallisto is ran to validate the RSEM results; 
* appropriately formatted logs are generated; 
* multiqc is ran to summarize everything as a nicely formatted report. 
    
In the end you are expected to obtain a number of new directories: FastQC, bams, tdfs_and_bws, RSEM, kallisto, stats, strand, featureCounts, exp_tables. Each directory would contain the files generated by its namesake, as well as all appropriate logs. The executed commands with all of the versions and exact options are recorded in the master log. 
    
    

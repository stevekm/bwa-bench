params.refDir = "ref/bwa/hg19"
params.inputDir = "input"

Channel.from([
    [file("${params.inputDir}/SeraCare-1to1-Positive_S2_L001_R1_001.fastq.gz"), file("${params.inputDir}/SeraCare-1to1-Positive_S2_L001_R2_001.fastq.gz")]
    ]).set { samples }

Channel.fromPath("${params.refDir}").set { refDir }

Channel.from(0..32).set { cpu_threads }

process download_samples {
    storeDir "${params.inputDir}"

    input:
    val(x) from Channel.from('')

    output:
    file('SeraCare-1to1-Positive_S2_L001_R1_001.fastq.gz')
    file('SeraCare-1to1-Positive_S2_L001_R2_001.fastq.gz')

    script:
    """
    wget https://genome.med.nyu.edu/results/external/NYU/snuderllab/data/NGS580/SeraCare-1to1-Positive_S2_L001_R1_001.fastq.gz
    wget https://genome.med.nyu.edu/results/external/NYU/snuderllab/data/NGS580/SeraCare-1to1-Positive_S2_L001_R2_001.fastq.gz
    """
}

process download_ref {
    storeDir "${params.refDir}"

    input:
    val(x) from Channel.from('')

    output:
    file('genome.fa')
    file('genome.fa.amb')
    file('genome.fa.ann')
    file('genome.fa.bwt')
    file('genome.fa.pac')
    file('genome.fa.sa')

    script:
    """
    wget https://genome.med.nyu.edu/results/external/NYU/snuderllab/ref/BWA/hg19/genome.fa
    wget https://genome.med.nyu.edu/results/external/NYU/snuderllab/ref/BWA/hg19/genome.fa.amb
    wget https://genome.med.nyu.edu/results/external/NYU/snuderllab/ref/BWA/hg19/genome.fa.ann
    wget https://genome.med.nyu.edu/results/external/NYU/snuderllab/ref/BWA/hg19/genome.fa.bwt
    wget https://genome.med.nyu.edu/results/external/NYU/snuderllab/ref/BWA/hg19/genome.fa.pac
    wget https://genome.med.nyu.edu/results/external/NYU/snuderllab/ref/BWA/hg19/genome.fa.sa
    """
}

def nslots = 0..32

process align {
    // first pass alignment with BWA
    tag "${slots}"
    cpus "${threads}"
    beforeScript "export NTHREADS=${threads}; ${process.beforeScript}"

    input:
    set file(fastqR1), file(fastqR2), file(refDir), val(threads) from samples.combine(refDir).combine(cpu_threads)
    // output:
    // set val(sampleID), file("${bam_file}") into samples_bam, samples_bam2
    // val(sampleID) into done_alignment

    script:
    output = "sample.sam"
    sampleID = "SeraCare"
    """
    bwa mem \
    -M -v 1 \
    -t \${NSLOTS:-\${NTHREADS:-1}} \
    -R '@RG\\tID:${sampleID}\\tSM:${sampleID}\\tLB:${sampleID}\\tPL:ILLUMINA' \
    "${refDir}/genome.fa" \
    "${fastqR1}" "${fastqR2}" > /dev/null
    """
}

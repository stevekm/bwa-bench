params.refDir = "ref/bwa/hg19"
params.inputDir = "input"
params.outputDir = "output"
params.maxCPUs = 32
params.minCPUs = 1
params.reps = 3

def maxCPUs = params.maxCPUs.toInteger()
def minCPUs = params.minCPUs.toInteger()
def workflowTimestamp = "${workflow.start.format('yyyy-MM-dd HH:mm:ss')}"
def workflowTimestamp_str = "${workflow.start.format('yyyy-MM-dd-HH-mm-ss')}"
def time_outputFile = "times-${workflowTimestamp_str}.tsv"
def reps = params.reps.toInteger()

log.info "~~~~~~~ BWA Benchmark Pipeline ~~~~~~~"
log.info "* Launch time:        ${workflowTimestamp}"
log.info "* Min CPUs:           ${minCPUs}"
log.info "* Max CPUs:           ${maxCPUs}"
log.info "* Reps:               ${reps}"
log.info "* Time Log File:      ${time_outputFile}"
log.info "* Output Dir:         ${params.outputDir}"
log.info "* Project dir:        ${workflow.projectDir}"
log.info "* Launch dir:         ${workflow.launchDir}"
log.info "* Work dir:           ${workflow.workDir.toUriString()}"
log.info "* Profile:            ${workflow.profile ?: '-'}"
log.info "* Script name:        ${workflow.scriptName ?: '-'}"
log.info "* Script ID:          ${workflow.scriptId ?: '-'}"
log.info "* Container engine:   ${workflow.containerEngine?:'-'}"
log.info "* Workflow session:   ${workflow.sessionId}"
log.info "* Nextflow run name:  ${workflow.runName}"
log.info "* Nextflow version:   ${workflow.nextflow.version}, build ${workflow.nextflow.build} (${workflow.nextflow.timestamp})"
log.info "* Launch command:\n${workflow.commandLine}\n"

// input sample data
// Channel.from([
//     [file("${params.inputDir}/SeraCare-1to1-Positive_S2_L001_R1_001.fastq.gz"), file("${params.inputDir}/SeraCare-1to1-Positive_S2_L001_R2_001.fastq.gz")]
//     ]).set { samples }

// directory with reference files needed
Channel.fromPath("${params.refDir}").set { refDir }

// make a list of the CPU threads to run on
Channel.from(minCPUs..maxCPUs).set { cpu_threads }

// download the sample data; ~743MB
process download_samples {
    storeDir "${params.inputDir}"

    input:
    val(x) from Channel.from('')

    output:
    set file('SeraCare-1to1-Positive_S2_L001_R1_001.fastq.gz'), file('SeraCare-1to1-Positive_S2_L001_R2_001.fastq.gz') into sample_fastqs


    script:
    """
    wget https://genome.med.nyu.edu/results/external/NYU/snuderllab/data/NGS580/SeraCare-1to1-Positive_S2_L001_R1_001.fastq.gz
    wget https://genome.med.nyu.edu/results/external/NYU/snuderllab/data/NGS580/SeraCare-1to1-Positive_S2_L001_R2_001.fastq.gz
    """
}

// download reference data; ~8GB
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

repeaters = 1..reps

process align {
    echo true
    tag "${threads}-${rep}"
    cpus "${threads}"
    memory { 2.GB * "${threads}".toInteger() }
    beforeScript "export NTHREADS=${threads}; ${params.beforeScript}"
    afterScript "${params.afterScript}"

    input:
    set file(fastqR1), file(fastqR2), file(refDir), val(threads) from sample_fastqs.combine(refDir).combine(cpu_threads)
    each rep from repeaters

    output:
    file("${output_tsv}") into align_times

    script:
    mem = 2 * "${threads}".toInteger()
    output_sam = "sample.sam"
    output_tsv = "time.tsv"
    sampleID = "SeraCare"
    """
    # name of current system
    NODE=\$(uname -n)
    # get the number of CPU threads to use
    JOBTHREADS=\${NSLOTS:-\${NTHREADS:-1}}

    # get the type of CPU being used
    if [ "\$(uname)" == "Darwin" ]; then
    CPULABEL="\$(sysctl -n machdep.cpu.brand_string)"
    elif [ "\$(uname)" == "Linux" ]; then
    CPULABEL="\$(cat /proc/cpuinfo | grep 'model name' | head -1 | cut -d ':' -f2 | sed -e 's|^ ||')"
    else
    CPULABEL="none"
    fi

    printf "time start: %s" "\$(date +"%Y-%m-%d %H:%M:%S")"

    ALIGNSTART=\$(date +%s)

    bwa mem \
    -M -v 1 \
    -t \${JOBTHREADS} \
    -R '@RG\\tID:${sampleID}\\tSM:${sampleID}\\tLB:${sampleID}\\tPL:ILLUMINA' \
    "${refDir}/genome.fa" \
    "${fastqR1}" "${fastqR2}" > "${output_sam}"

    ALIGNSTOP=\$((\$(date +%s) - \${ALIGNSTART:-0}))

    printf "time stop: %s" "\$(date +"%Y-%m-%d %H:%M:%S")"

    CPUSEC="\$(grep 'Real time' .command.err | cut -d ';' -f2 | sed -e 's|^[^[:digit:]]*\\([[:digit:]]*\\.[[:digit:]]*\\).*\$|\\1|')"

    printf "\${JOBTHREADS}\t${mem}\t\${ALIGNSTOP:-none}\t\${CPUSEC:-none}\t\${NODE:-none}\t\${CPULABEL:-none}\n" > "${output_tsv}"

    rm -f "${output_sam}"
    """
}
align_times.collectFile(name: "${time_outputFile}", storeDir: "${params.outputDir}")

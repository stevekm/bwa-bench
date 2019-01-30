SHELL:=/bin/bash
HOSTNAME:=$(shell uname -n)
UNAME:=$(shell uname)
TIMESTAMP:=$(shell date +%s)
TIMESTAMP_str:=$(shell date +"%Y-%m-%d-%H-%M-%S")
DIRNAME:=$(shell python -c 'import os; print(os.path.basename(os.path.realpath(".")))')
# no default action
none:

# ~~~~~ SETUP PIPELINE ~~~~~ #
./nextflow:
	curl -fsSL get.nextflow.io | bash

install: ./nextflow


# ~~~~~ SETUP CONDA ~~~~~ #
ifeq ($(UNAME), Darwin)
CONDASH:=Miniconda3-4.5.4-MacOSX-x86_64.sh
CONDAURL:=https://repo.continuum.io/miniconda/$(CONDASH)
PATH:=$(CURDIR)/conda/bin:$(PATH)
unexport PYTHONPATH
unexport PYTHONHOME
endif

conda:
ifeq ($(UNAME), Darwin)
	wget "$(CONDAURL)" && \
	bash "$(CONDASH)" -b -p conda && \
	rm -f "$(CONDASH)"
endif

# ~~~~~ RUN PIPELINE ~~~~~ #
MAXCPUS:=$(shell getconf _NPROCESSORS_ONLN)
LOGDIR:=logs
LOGFILE:=$(LOGDIR)/bwa-bench.$(TIMESTAMP_str).log
# extra params (from user)
EP:=
# run params (from makefile)
RP:=
run: install
	if grep -q 'bigpurple' <<<'$(HOSTNAME)'; then $(MAKE) run-log RP='-profile bigpurpleSingularity'; \
	elif grep -q 'phoenix' <<<'$(HOSTNAME)'; then module unload java && module load java/1.8 && $(MAKE) run-log RP='-profile phoenix'; \
	elif [ "$$(uname)" == "Darwin" ]; then $(MAKE) conda run-log RP='-profile conda'; \
	else $(MAKE) run-log ; fi
run-log:
	$(MAKE) run-recurse 2>&1 | tee -a "$(LOGFILE)"
run-recurse:
	NXF_VER=18.12.0-edge ./nextflow -trace nextflow.executor run main.nf --maxCPUs "$(MAXCPUS)" $(RP) $(EP)




# save a record of the most recent Nextflow run completion
PRE:=
RECDIR:=recorded-runs/$(PRE)$(DIRNAME)_$(TIMESTAMP_str)
STDOUTLOGPATH:=
STDOUTLOG:=
ALL_LOGS:=
record: STDOUTLOGPATH=$(shell ls -d -1t $(LOGDIR)/bwa-bench.*.log | head -1 | python -c 'import sys, os; print(os.path.realpath(sys.stdin.readlines()[0].strip()))' )
record: STDOUTLOG=$(shell basename "$(STDOUTLOGPATH)")
record: ALL_LOGS=$(shell find "$(LOGDIR)" -type f -name '*$(STDOUTLOG)*')
record:
	@mkdir -p "$(RECDIR)" && \
	cp -a *.html trace.txt .nextflow.log main.nf nextflow.config "$(RECDIR)/" && \
	for item in $(ALL_LOGS); do cp -a "$${item}" "$(RECDIR)/"; done ; \
	echo ">>> Copied execution reports and logs to: $(RECDIR)"

# ~~~~~ CLEANUP ~~~~~ #
# commands to clean out items in the current directory after running the pipeline
clean-traces:
	rm -f trace*.txt.*

clean-logs:
	rm -f .nextflow.log.*

clean-reports:
	rm -f *.html.*

clean-flowcharts:
	rm -f *.dot.*

clean-output:
	[ -d output ] && mv output oldoutput && rm -rf oldoutput &

clean-work:
	[ -d work ] && mv work oldwork && rm -rf oldwork &

# clean all files produced by previous pipeline runs
clean: clean-logs clean-traces clean-reports clean-flowcharts
clean-all: clean clean-output clean-work

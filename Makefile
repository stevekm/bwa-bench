SHELL:=/bin/bash
HOSTNAME:=$(shell uname -n)
UNAME:=$(shell uname)
TIMESTAMP:=$(shell date +%s)
TIMESTAMP_str:=$(shell date +"%Y-%m-%d-%H-%M-%S")

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
LOGFILE:=logs/bwa-bench.$(TIMESTAMP_str).log
# extra params (from user)
EP:=
# run params (from makefile)
RP:=
run: install
	if grep -q 'bigpurple' <<<'$(HOSTNAME)'; then $(MAKE) run-log RP='-profile bigpurple'; \
	elif grep -q 'phoenix' <<<'$(HOSTNAME)'; then module unload java && module load java/1.8 && $(MAKE) run-log RP='-profile phoenix'; \
	elif [ "$$(uname)" == "Darwin" ]; then $(MAKE) conda run-log RP='-profile conda'; \
	else $(MAKE) run-log ; fi
run-log:
	$(MAKE) run-recurse 2>&1 | tee -a "$(LOGFILE)"
run-recurse:
	./nextflow run main.nf --maxCPUs "$(MAXCPUS)" $(RP) $(EP)




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

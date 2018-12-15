SHELL:=/bin/bash
none:

# ~~~~~ SETUP PIPELINE ~~~~~ #
./nextflow:
	curl -fsSL get.nextflow.io | bash

install: ./nextflow


# ~~~~~ RUN PIPELINE ~~~~~ #
run: install
	./nextflow run main.nf $(EP)

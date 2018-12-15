FROM ubuntu:16.04

RUN apt-get update && \
\
apt-get install -y wget \
bzip2 \
gcc \
make \
zlib1g-dev

RUN cd /opt/ && \
wget https://github.com/lh3/bwa/releases/download/v0.7.17/bwa-0.7.17.tar.bz2 && \
tar xvfj bwa-0.7.17.tar.bz2 && \
rm -f bwa-0.7.17.tar.bz2 && \
cd bwa-0.7.17 && \
make
ENV PATH="/opt/bwa-0.7.17:${PATH}"

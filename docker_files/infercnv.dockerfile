# Docker file for inferCNV
FROM r-base:3.5.2

LABEL org.label-schema.license="BSD-3-Clause" \
      org.label-schema.vendor="Broad Institute" \
      maintainer="Eric Weitz <eweitz@broadinstitute.org>"

RUN apt-get update && \
apt-get -y install curl libssl-dev libcurl4-openssl-dev libxml2-dev git python3 jags
RUN echo "options(repos = c(CRAN = 'https://cran.rstudio.com'))" >.Rprofile && \
echo "install.packages(c('devtools', 'RColorBrewer', 'gplots', 'futile.logger', 'ape', 'Matrix', 'fastcluster', 'dplyr', 'ggplot2', 'coin', 'caTools', 'reshape', 'rjags', 'fitdistrplus', 'future', 'foreach', 'doParallel', 'tidyr', 'parallel', 'coda', 'gridExtra', 'argparse'), dependencies = TRUE)" > install_devtools.r && \
echo "install.packages('BiocManager')" >> install_devtools.r && \
echo "BiocManager::install('BiocGenerics', version = '3.8')" >> install_devtools.r && \
echo "BiocManager::install('SummarizedExperiment', version = '3.8')" >> install_devtools.r && \
echo "BiocManager::install('SingleCellExperiment', version = '3.8')" >> install_devtools.r && \
echo "BiocManager::install('BiocStyle', version = '3.8')" >> install_devtools.r && \
echo "BiocManager::install('edgeR', version = '3.8')" >> install_devtools.r && \
echo "install.packages(c('HiddenMarkov', 'fitdistrplus', 'fastcluster', 'Matrix', 'stats', 'gplots', 'utils', 'methods', 'knitr', 'testthat'), dependencies = TRUE)" >> install_devtools.r && \
echo "library('devtools')" >> install_devtools.r && R --no-save < install_devtools.r

# Install Java, needed for Cromwell
RUN apt-get install -y openjdk-8-jdk

RUN echo "install.packages(c('optparse', 'logging'), dependencies = TRUE)" > install_devtools_dev.r && \
echo "library('devtools')" >> install_devtools_dev.r && R --no-save < install_devtools_dev.r

RUN mkdir /workflow

WORKDIR /
# RUN echo "Clear Docker cache (3)"
# RUN curl -OL "https://github.com/broadinstitute/infercnv/archive/InferCNV-v0.99.0.tar.gz"
# RUN tar -xvzf InferCNV-v0.99.0.tar.gz
# RUN R CMD INSTALL infercnv-InferCNV-v0.99.0
# RUN mv infercnv-InferCNV-v0.99.0/ inferCNV

RUN echo "Clear Docker cache (4)"
RUN git clone https://github.com/broadinstitute/inferCNV
WORKDIR inferCNV
RUN git checkout master
# Checkout code as of 2019-03-20
RUN git checkout devel
RUN git checkout cc4a81288d6dce7d77c0320086ad6a323ad4329b
RUN R CMD INSTALL .

# Delete extraneous inferCNV directories
WORKDIR /inferCNV
RUN rm -rf example/full_precision __simulations .git

# clean up installs
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Get script to convert inferCNV outputs to Ideogram.js annotations, then clean
RUN echo "Clearing Docker cache (3)"
WORKDIR /
RUN git clone https://github.com/broadinstitute/single_cell_portal scp
WORKDIR scp
RUN git checkout ew-refine-infercnv
# Checkout code as of 2019-03-20
RUN git checkout 46893f766d6441e2577d0e067d92c27c684c89c2
WORKDIR /
RUN mkdir -p single_cell_portal/scripts
RUN mv scp/scripts/ideogram single_cell_portal/scripts/
RUN mv scp/scripts/scp_to_infercnv.py single_cell_portal/scripts/
RUN mv scp/WDL/infercnv/* /workflow/
RUN rm -rf scp

# set path
ENV PATH=${PATH}:/inferCNV/scripts:/single_cell_portal/scripts

# Finish setting up workflow test scaffolding
WORKDIR /workflow
ADD https://github.com/broadinstitute/cromwell/releases/download/38/cromwell-38.jar .
RUN cp -p /inferCNV/example/oligodendroglioma_expression_downsampled.counts.matrix test_data/

WORKDIR /

#RUN rm /InferCNV-v0.8.2.tar.gz
CMD inferCNV.R --help
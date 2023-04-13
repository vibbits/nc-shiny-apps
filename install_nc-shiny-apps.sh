#!/bin/bash
set -e

# script: install_nc-shiny-apps.sh
# Improvements by Thomas Standaert on the current file from:
# https://github.com/vibbits/nc-shiny-apps/blob/main/install_nc-shiny-apps.sh

SHINY_SERVER_VERSION=${1:-${SHINY_SERVER_VERSION:-latest}}

# Run dependency scripts
. /rocker_scripts/install_s6init.sh
. /rocker_scripts/install_pandoc.sh

if [ "$SHINY_SERVER_VERSION" = "latest" ]; then
  SHINY_SERVER_VERSION=$(wget -qO- https://download3.rstudio.org/ubuntu-14.04/x86_64/VERSION)
fi

# Get apt packages
apt-get update
apt-get install -y --no-install-recommends \
    sudo \
    gdebi-core \
    libcurl4-gnutls-dev \
    libcairo2-dev \
    libxt-dev \
    xtail \
    wget \
    liblzma-dev \
    bzip2-doc \
    libbz2-dev \
    libxml2-dev

# note: previous attempts failed because libbz2-dev requires bzip2-doc (now edited)
#       which was excluded, probably because of --no-install-recommends

# Install Shiny server
wget --no-verbose "https://download3.rstudio.org/ubuntu-14.04/x86_64/shiny-server-${SHINY_SERVER_VERSION}-amd64.deb" -O ss-latest.deb
gdebi -n ss-latest.deb
rm ss-latest.deb

# Get R packages
install2.r --error --skipinstalled shiny rmarkdown

# Set up directories and permissions
#if [ -x "$(command -v rstudio-server)" ]; then
#  DEFAULT_USER=${DEFAULT_USER:-rstudio}
#  adduser ${DEFAULT_USER} shiny
#fi

cp -R /usr/local/lib/R/site-library/shiny/examples/* /srv/shiny-server/
chown shiny:shiny /var/lib/shiny-server
mkdir -p /var/log/shiny-server
chown shiny:shiny /var/log/shiny-server

# create init scripts
mkdir -p /etc/services.d/shiny-server
cat > /etc/services.d/shiny-server/run << 'EOF'
#!/usr/bin/with-contenv bash
## load /etc/environment vars first:
for line in $( cat /etc/environment ) ; do export $line > /dev/null; done
if [ "$APPLICATION_LOGS_TO_STDOUT" != "false" ]; then
    exec xtail /var/log/shiny-server/ &
fi
exec shiny-server 2>&1
EOF
chmod +x /etc/services.d/shiny-server/run

# Clean up
rm -rf /var/lib/apt/lists/*
rm -rf /tmp/downloaded_packages

## build ARGs
##NCPUS=${NCPUS:-1}

##apt-get update -qq && apt-get -y --no-install-recommends install \
##    libxml2-dev \
##    libcairo2-dev \
##    libgit2-dev \
##    default-libmysqlclient-dev \
##    libpq-dev \
##    libsasl2-dev \
##    libsqlite3-dev \
##    libssh2-1-dev \
##    libxtst6 \
##    libcurl4-openssl-dev \
##    unixodbc-dev && \
##  rm -rf /var/lib/apt/lists/*

# sorted list of packages required by the current shiny apps
install2.r --error --skipinstalled \
    BiocManager \
    data.table \
    devtools \
    DT \
    ggplot2 \
    ggrepel \
    grDevices \
    grid \
    gridExtra \
    lattice \
    latticeExtra \
    openxlsx \
    pheatmap \
    RColorBrewer \
    readr \
    rlist \
    scales \
    seqinr \
    shinyBS \
    shinyjs \
    stringr \
    VennDiagram

# the following two blocks could not be added to the above command
# because install2.r expects package names and does not support
# more complex syntax like devtools::install_github("vqv/ggbiplot")
# nor BiocManager::install("Rhtslib")

# additional installs using devtools::install
Rscript -e 'devtools::install_github("vqv/ggbiplot")'

# additional instals using bioconductor: BiocManager::install
Rscript -e 'BiocManager::install(c("Rhtslib",
                    "Rsamtools",
                    "GenomicAlignments",
                    "rtracklayer",
                    "ShortRead",
                    "GenomicFeatures",
                    "EDASeq"))'

## a bridge to far? -- brings in another 60 packages
# install2.r --error --skipinstalled -n $NCPUS tidymodels

# cleanup
 rm -rf /tmp/downloaded_packages
 
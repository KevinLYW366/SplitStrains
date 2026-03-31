# Use Ubuntu 18.04 as base image
FROM ubuntu:18.04

# Set environment variables to avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    PATH="/opt/conda/envs/SplitStrains/bin:/opt/conda/bin:$PATH" \
    CONDA_AUTO_ACTIVATE_BASE=false

# Update apt sources to use Chinese mirrors (Aliyun)
RUN sed -i 's/archive.ubuntu.com/mirrors.aliyun.com/g' /etc/apt/sources.list && \
    sed -i 's/security.ubuntu.com/mirrors.aliyun.com/g' /etc/apt/sources.list

# Install basic dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    ca-certificates \
    bzip2 \
    gcc \
    g++ \
    make \
    zlib1g-dev \
    libncurses5-dev \
    libbz2-dev \
    liblzma-dev \
    libcurl4-openssl-dev \
    libssl-dev \
    default-jre \
    && rm -rf /var/lib/apt/lists/*

# Download and install Miniconda with Python 3.6
RUN wget https://repo.anaconda.com/miniconda/Miniconda3-py310_24.11.1-0-Linux-x86_64.sh -O /tmp/miniconda.sh && \
    bash /tmp/miniconda.sh -b -p /opt/conda && \
    rm /tmp/miniconda.sh

# Configure conda to use Chinese mirrors (Tsinghua)
RUN conda config --add channels https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/main/ && \
    conda config --add channels https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/free/ && \
    conda config --add channels https://mirrors.tuna.tsinghua.edu.cn/anaconda/cloud/conda-forge/ && \
    conda config --add channels https://mirrors.tuna.tsinghua.edu.cn/anaconda/cloud/bioconda/ && \
    conda config --set show_channel_urls yes && \
    conda config --set channel_priority flexible && \
    conda config --set auto_activate_base false

# Install mamba for faster package management
RUN conda install -y -c conda-forge mamba

# Create a new environment named SplitStrains with Python 3.6
RUN mamba create -y -n SplitStrains python=3.6

# Install all packages into the SplitStrains environment using mamba
RUN mamba install -y -n SplitStrains \
    matplotlib=3.3 \
    mixem=0.1 \
    numpy=1.19 \
    numpydoc=0.8 \
    pysam=0.15 \
    scipy=1.1 \
    seaborn=0.9 \
    scikit-learn=0.24 && \
    mamba install -y -n SplitStrains -c bioconda \
    bwa=0.7 \
    trimmomatic=0.40 \
    samtools=1.18 \
    art=2016.06.05

# Create a wrapper script for trimmomatic to make it easier to use
# Note: We need to activate the SplitStrains environment to find trimmomatic
RUN echo '#!/bin/bash\nsource /opt/conda/etc/profile.d/conda.sh && conda activate SplitStrains && java -jar $(which trimmomatic-0.40.jar) "$@"' > /usr/local/bin/trimmomatic && \
    chmod +x /usr/local/bin/trimmomatic

# Copy the current directory into the container so docker build works from here
COPY . /opt/SplitStrains

# Process the reference genome: modify the header and create index
RUN samtools faidx /opt/SplitStrains/refs/tuberculosis.fna && \
    bwa index /opt/SplitStrains/refs/tuberculosis.fna

# Install a command-style launcher so splitStrains is available on PATH
RUN printf '%s\n' '#!/bin/bash' 'exec python /opt/SplitStrains/splitStrains.py "$@"' > /usr/local/bin/splitStrains && \
    chmod +x /usr/local/bin/splitStrains

# Set the working directory to SplitStrains
WORKDIR /opt/SplitStrains

# Verify installations in the SplitStrains environment
RUN /bin/bash -c "source /opt/conda/etc/profile.d/conda.sh && \
    conda activate SplitStrains && \
    python --version && \
    bwa 2>&1 | head -3 && \
    samtools --version && \
    trimmomatic -version && \
    art_illumina 2>&1 | head -5"

# Clean up conda and mamba cache to reduce image size
RUN conda clean -ya && \
    mamba clean -ya

# Create a script to activate the environment and run bash
RUN echo '#!/bin/bash\nsource /opt/conda/etc/profile.d/conda.sh\nconda activate SplitStrains\nexec "$@"' > /docker-entrypoint.sh && \
    chmod +x /docker-entrypoint.sh

# Set entrypoint to activate SplitStrains environment
ENTRYPOINT ["/docker-entrypoint.sh"]

# Set the default command to bash
CMD ["/bin/bash"]

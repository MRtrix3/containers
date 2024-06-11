ARG MAKE_JOBS="1"
ARG DEBIAN_FRONTEND="noninteractive"

FROM debian:bullseye-backports AS base
FROM buildpack-deps:bullseye AS base-builder

FROM base-builder as mrtrix3-builder

# Git commitish from which to build MRtrix3.
ARG MRTRIX3_GIT_COMMITISH="dev"
# Command-line arguments for `./configure`
ARG MRTRIX3_CONFIGURE_FLAGS="-nogui"
# Command-line arguments for `./build`
ARG MRTRIX3_BUILD_FLAGS="-persistent -nopaginate"

RUN apt-get -qq update \
    && apt-get install -yq --no-install-recommends \
        libeigen3-dev \
        libfftw3-dev \
        libpng-dev \
        libtiff5-dev \
        python-is-python3 \
        zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# Clone, build, and install MRtrix3.
ARG MAKE_JOBS
WORKDIR /opt/mrtrix3
RUN git clone -b ${MRTRIX3_GIT_COMMITISH} --depth 1 https://github.com/MRtrix3/mrtrix3.git . \
    && ./configure $MRTRIX3_CONFIGURE_FLAGS  \
    && NUMBER_OF_PROCESSORS=$MAKE_JOBS ./build $MRTRIX3_BUILD_FLAGS

# Install AFNI
FROM base-builder AS afni-builder
WORKDIR /opt/afni
RUN apt-get -qq update \
    && apt-get install -yq --no-install-recommends \
        rsync \
        tcsh
RUN curl -O https://afni.nimh.nih.gov/pub/dist/bin/misc/@update.afni.binaries
RUN tcsh @update.afni.binaries -package linux_ubuntu_16_64 -bindir /opt/afni

# Install ART ACPCdetect.
FROM base-builder as acpcdetect-builder
WORKDIR /opt/art
COPY acpcdetect_V2.1_LinuxCentOS6.7.tar.gz /opt/art/acpcdetect_V2.1_LinuxCentOS6.7.tar.gz
RUN tar -xf acpcdetect_V2.1_LinuxCentOS6.7.tar.gz

# Compile and install ANTs.
FROM base-builder as ants-builder
RUN apt-get -qq update \
    && apt-get install -yq --no-install-recommends \
        cmake \
        make \
    && rm -rf /var/lib/apt/lists/*
ARG MAKE_JOBS
WORKDIR /src/ants
RUN curl -fsSL https://github.com/ANTsX/ANTs/archive/v2.4.3.tar.gz \
    | tar xz --strip-components 1 \
    && mkdir build \
    && cd build \
    && cmake \
        -DBUILD_SHARED_LIBS:BOOL=OFF \
        -DBUILD_TESTING:BOOL=OFF \
        -DCMAKE_BUILD_TYPE:STRING=Release \
        -DCMAKE_INSTALL_PREFIX:PATH=/opt/ants \
        -DRUN_LONG_TESTS:BOOL=OFF \
        -DRUN_SHORT_TESTS:BOOL=OFF \
        .. \
    && make -j $MAKE_JOBS \
    && cd ANTS-build \
    && make install \
    && cp /src/ants/ANTSCopyright.txt /opt/ants/ANTSCopyright.txt

# Install FreeSurfer
FROM base-builder AS freesurfer-installer
WORKDIR /opt/freesurfer
RUN curl -fsSL https://surfer.nmr.mgh.harvard.edu/pub/dist/freesurfer/7.3.2/freesurfer-linux-ubuntu20_amd64-7.3.2.tar.gz \
    | tar xz --strip-components 1

# Install FSL.
FROM base-builder AS fsl-installer
WORKDIR /opt/fsl
COPY FSL_source.txt source.txt
RUN curl -fL -# --retry 5 https://fsl.fmrib.ox.ac.uk/fsldownloads/fsl-6.0.4-centos6_64.tar.gz \
    | tar -xz --strip-components 1
# Install fslpython in a separate layer to preserve the cache of the (long) download.
RUN apt-get -qq update \
    && apt-get install -yq --no-install-recommends \
        bc \
        dc \
        file \
        libfontconfig1 \
        libfreetype6 \
        libgl1-mesa-dev \
        libgl1-mesa-dri \
        libglu1-mesa-dev \
        libgomp1 \
        libice6 \
        libopenblas-base \
        libxcursor1 \
        libxft2 \
        libxinerama1 \
        libxrandr2 \
        libxrender1 \
        libxt6 \
        python2.7 \
        sudo \
        wget \
    && rm -rf /var/lib/apt/lists/* \
    && bash /opt/fsl/etc/fslconf/fslpython_install.sh -f /opt/fsl

# Install HD-BET
FROM base-builder as hdbet-installer
WORKDIR /opt/hdbet
RUN git clone https://github.com/MIC-DKFZ/HD-BET .

# Obtain MNI template data to be used in executing exemplar commands
FROM base-builder as mni-installer
WORKDIR /opt/mni
RUN wget http://www.bic.mni.mcgill.ca/~vfonov/icbm/2009/mni_icbm152_nlin_asym_09c_nifti.zip \
    && unzip -j mni_icbm152_nlin_asym_09c_nifti.zip

# Build final image
FROM base as final

RUN apt-get -qq update \
    && apt-get install -yq --no-install-recommends \
        bzip2 \
        ca-certificates \
        curl \
        dc \
        libfftw3-3 \
        libgomp1 \
        liblapack3 \
        libpng16-16 \
        libquadmath0 \
        libtiff5 \
        pigz \
        python3-distutils \
        python3-pip \
    && rm -rf /var/lib/apt/lists/*

COPY --from=mrtrix3-builder /opt/mrtrix3 /opt/mrtrix3
COPY --from=afni-builder /opt/afni /opt/afni
COPY --from=acpcdetect-builder /opt/art /opt/art
COPY --from=ants-builder /opt/ants /opt/ants
COPY --from=fsl-installer /opt/fsl /opt/fsl
COPY --from=freesurfer-installer /opt/freesurfer /opt/freesurfer
COPY --from=hdbet-installer /opt/hdbet /opt/hdbet
COPY --from=mni-installer /opt/mni /opt/mni

RUN ln -s /usr/bin/python3 /usr/bin/python
RUN cd /opt/hdbet && pip install -e .

COPY cmds-to-minify.sh /cmds-to-minify.sh
COPY mrtrix.conf /etc/mrtrix.conf
WORKDIR /

ENV ANTSPATH=/opt/ants/bin \
    ARTHOME=/opt/art \
    FREESURFER_HOME=/opt/freesurfer \
    FSLDIR=/opt/fsl \
    FSLOUTPUTTYPE=NIFTI_GZ \
    FSLMULTIFILEQUIT=TRUE \
    FSLTCLSH=/opt/fsl/bin/fsltclsh \
    FSLWISH=/opt/fsl/bin/fslwish \
    LD_LIBRARY_PATH="$LD_LIBRARY_PATH:/opt/fsl/lib:/opt/ants/lib:" \
    PATH="/opt/mrtrix3/bin:/opt/afni:/opt/ants/bin:/opt/art/bin:/opt/freesurfer/bin:/opt/fsl/bin:/opt/hdbet/HD_BET:$PATH"

ENTRYPOINT ["/bin/bash"]


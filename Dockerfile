ARG MAKE_JOBS="1"
ARG DEBIAN_FRONTEND="noninteractive"

FROM debian:bookworm as base
FROM buildpack-deps:bookworm AS base-builder

FROM base-builder as mrtrix3-builder

# Git commitish from which to build MRtrix3.
ARG MRTRIX3_GIT_COMMITISH="master"
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
        python3 \
        zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# Clone, build, and install MRtrix3.
ARG MAKE_JOBS
WORKDIR /opt/mrtrix3
RUN git clone -b ${MRTRIX3_GIT_COMMITISH} --depth 1 https://github.com/MRtrix3/mrtrix3.git . \
    && python3 ./configure $MRTRIX3_CONFIGURE_FLAGS \
    && NUMBER_OF_PROCESSORS=$MAKE_JOBS python3 ./build $MRTRIX3_BUILD_FLAGS \
    && rm -rf testing/ tmp/

# Install ART ACPCdetect.
from base-builder as acpcdetect-builder
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
RUN curl -fsSL https://github.com/ANTsX/ANTs/archive/v2.5.2.tar.gz \
    | tar xz --strip-components 1 \
    && mkdir build \
    && cd build \
    && cmake \
        -DBUILD_ALL_ANTS_APPS:BOOL=OFF \
        -DBUILD_SHARED_LIBS:BOOL=OFF \
        -DBUILD_TESTING:BOOL=OFF \
        -DCMAKE_BUILD_TYPE:STRING=Release \
        -DCMAKE_INSTALL_PREFIX:PATH=/opt/ants \
        -DRUN_LONG_TESTS:BOOL=OFF \
        -DRUN_SHORT_TESTS:BOOL=OFF \
#        --target=N4BiasFieldCorrection \
        .. \
    && make -j $MAKE_JOBS \
    && cd ANTS-build \
    && make install \
    && cp /src/ants/ANTSCopyright.txt /opt/ants/

# Install FreeSurfer LUT
FROM base-builder AS freesurfer-installer
WORKDIR /opt/freesurfer
RUN curl -fsSLO https://raw.githubusercontent.com/freesurfer/freesurfer/v7.1.1/distribution/FreeSurferColorLUT.txt

# Install FSL.
FROM base-builder AS fsl-installer
WORKDIR /opt/fsl
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
        libopenblas0 \
        libxcursor1 \
        libxft2 \
        libxinerama1 \
        libxrandr2 \
        libxrender1 \
        libxt6 \
        python3 \
        sudo \
        wget \
    && rm -rf /var/lib/apt/lists/*
RUN wget https://fsl.fmrib.ox.ac.uk/fsldownloads/fslinstaller.py \
    && python3 fslinstaller.py -V 6.0.7.7 -d /opt/fsl -m -o
# Have to run this after the installation script;
#   it wipes all pre-existing contents of the directory
COPY FSL_source.txt source.txt

FROM base as final

RUN apt-get -qq update \
    && apt-get install -yq --no-install-recommends \
        bzip2 \
        ca-certificates \
        curl \
        dc \
        libfftw3-single3 \
        libfftw3-double3 \
        libgomp1 \
        liblapack3 \
        libpng16-16 \
        libquadmath0 \
        libtiff5-dev \
        pigz \
        python3 \
        python3-distutils \
    && rm -rf /var/lib/apt/lists/*

COPY --from=mrtrix3-builder /opt/mrtrix3 /opt/mrtrix3
COPY --from=acpcdetect-builder /opt/art /opt/art
COPY --from=ants-builder /opt/ants /opt/ants
COPY --from=fsl-installer /opt/fsl /opt/fsl
COPY --from=freesurfer-installer /opt/freesurfer /opt/freesurfer

RUN ln -s /usr/bin/python3 /usr/bin/python

COPY cmds-to-minify.sh /cmds-to-minify.sh
WORKDIR /

ENV ANTSPATH=/opt/ants/bin \
    ARTHOME=/opt/art \
    FREESURFER_HOME=/opt/freesurfer \
    FSLDIR=/opt/fsl \
    FSLOUTPUTTYPE=NIFTI_GZ \
    FSLMULTIFILEQUIT=TRUE \
    FSLTCLSH=/opt/fsl/bin/fsltclsh \
    FSLWISH=/opt/fsl/bin/fslwish \
    LD_LIBRARY_PATH="$LD_LIBRARY_PATH:/opt/fsl/lib:/opt/ants/lib" \
    PATH="/opt/mrtrix3/bin:/opt/ants/bin:/opt/art/bin:/opt/fsl/share/fsl/bin:$PATH"

ENTRYPOINT ["/bin/bash"]


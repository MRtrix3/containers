ARG MAKE_JOBS="1"
ARG DEBIAN_FRONTEND="noninteractive"

FROM debian:buster as base
FROM buildpack-deps:buster AS base-builder

FROM base-builder as mrtrix3-builder

# Git commit from which to build MRtrix3.
ARG MRTRIX3_GIT_COMMITISH="master"
# Command-line arguments for `./configure`
ARG MRTRIX3_CONFIGURE_FLAGS=""
# Command-line arguments for `./build`
ARG MRTRIX3_BUILD_FLAGS=""

RUN apt-get -qq update \
    && apt-get install -yq --no-install-recommends \
        dc \
        libeigen3-dev \
        libfftw3-dev \
        libgl1-mesa-dev \
        libpng-dev \
        libqt5opengl5-dev \
        libqt5svg5-dev \
        libtiff5-dev \
        qt5-default \
        zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# Clone, build, and install MRtrix3.
ARG MAKE_JOBS
WORKDIR /opt/mrtrix3
RUN git clone -b ${MRTRIX3_GIT_COMMITISH} --depth 1 https://github.com/MRtrix3/mrtrix3.git . \
    && ./configure $MRTRIX3_CONFIGURE_FLAGS \
    && NUMBER_OF_PROCESSORS=$MAKE_JOBS ./build $MRTRIX3_BUILD_FLAGS

# Compile and  install ANTs.
FROM base-builder as ants-builder
RUN apt-get -qq update \
    && apt-get install -yq --no-install-recommends \
        cmake \
    && rm -rf /var/lib/apt/lists/*
ARG MAKE_JOBS
WORKDIR /src/ants
RUN curl -fsSL https://github.com/ANTsX/ANTs/archive/v2.3.4.tar.gz \
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
        --target=N4BiasFieldCorrection \
        .. \
    && make -j $MAKE_JOBS \
    && cd ANTS-build \
    && make install

# Install FreeSurfer LUT
FROM base-builder AS freesurfer-installer
WORKDIR /opt/freesurfer
RUN curl -fsSLO https://raw.githubusercontent.com/freesurfer/freesurfer/v7.1.1/distribution/FreeSurferColorLUT.txt

# Install FSL.
FROM base-builder AS fsl-installer
WORKDIR /opt/fsl
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
        sudo \
        wget \
    && rm -rf /var/lib/apt/lists/* \
    && bash /opt/fsl/etc/fslconf/fslpython_install.sh -f /opt/fsl

FROM base as final
COPY --from=mrtrix3-builder /opt/mrtrix3 /opt/mrtrix3
COPY --from=ants-builder /opt/ants /opt/ants
COPY --from=fsl-installer /opt/fsl /opt/fsl
COPY --from=freesurfer-installer /opt/freesurfer /opt/freesurfer

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
        libxcursor1 \
        libxft2 \
        libxinerama1 \
        libxrandr2 \
        libxrender1 \
        libxt6 \
    && rm -rf /var/lib/apt/lists/*

RUN apt-get -qq update \
    && apt-get install -yq --no-install-recommends \
        dc \
        libeigen3-dev \
        libfftw3-dev \
        libgl1-mesa-dev \
        libpng-dev \
        libqt5opengl5-dev \
        libqt5svg5-dev \
        libtiff5-dev \
        python3-distutils \
        qt5-default \
        zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

RUN ln -s /usr/bin/python3 /usr/bin/python

WORKDIR /work
COPY . .

ENV ANTSPATH=/opt/ants/bin \
    FREESURFER_HOME=/opt/freesurfer \
    FSLDIR=/opt/fsl \
    LD_LIBRARY_PATH="$LD_LIBRARY_PATH:/opt/fsl/lib:/opt/ants/lib:" \
    PATH="/opt/ants/bin:/opt/fsl/bin:/opt/mrtrix3/bin:$PATH"

ENV FSLOUTPUTTYPE=NIFTI_GZ \
    FSLMULTIFILEQUIT=TRUE \
    FSLTCLSH=$FSLDIR/bin/fsltclsh \
    FSLWISH=$FSLDIR/bin/fslwish

ENTRYPOINT ["/bin/bash"]

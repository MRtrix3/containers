FROM neurodebian:nd18.04-non-free

# Git commit from which to build MRtrix3.
ARG MRTRIX3_GIT_COMMITISH="master"
# Command-line arguments for `./configure`
ARG MRTRIX3_CONFIGURE_FLAGS=""
# Command-line arguments for `./build`
ARG MRTRIX3_BUILD_FLAGS=""
# Temporary dependencies that can be removed after MRtrix3 build
ARG MRTRIX3_TEMP_DEPS="g++ git libeigen3-dev"

# Prevent programs like `apt-get` from presenting interactive prompts.
ARG DEBIAN_FRONTEND="noninteractive"

# Install MRtrix3 compile-time dependencies.
RUN apt-get -qq update \
    && apt-get install -yq --no-install-recommends \
          $MRTRIX3_TEMP_DEPS \
          ca-certificates \
          curl \
          libfftw3-dev \
          libgl1-mesa-dev \
          libpng-dev \
          libqt5opengl5-dev \
          libqt5svg5-dev \
          libtiff5-dev \
          python \
          qt5-default \
          zlib1g-dev

# Clone, build, and install MRtrix3.
WORKDIR /opt/mrtrix3
RUN git clone https://github.com/MRtrix3/mrtrix3.git . \
    && git checkout $MRTRIX3_GIT_COMMITISH \
    && ./configure $MRTRIX3_CONFIGURE_FLAGS \
    && ./build $MRTRIX3_BUILD_FLAGS \
    && apt-get remove --purge -y $MRTRIX3_TEMP_DEPS

# Install ANTs and FSL.
RUN apt-get -qq update \
    && apt-get install -yq --no-install-recommends \
          "ants=2.2.0-1ubuntu1" \
          "fsl=5.0.9-5~nd18.04+1" \
          "fsl-first-data" \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    # Install eddy. The sources are private now, so neurodebian no longer provides it.
    && . /etc/fsl/fsl.sh \
    && cd $FSLDIR/bin \
    && curl -fsSLO https://fsl.fmrib.ox.ac.uk/fsldownloads/patches/eddy-patch-fsl-5.0.9/centos6/eddy_openmp \
    && ln -s eddy_openmp eddy \
    && chmod +x eddy_openmp

ENV PATH="/opt/mrtrix3/bin:$PATH"

WORKDIR /work

ENTRYPOINT ["bash", "-c", "source /etc/fsl/fsl.sh && bash $@"]

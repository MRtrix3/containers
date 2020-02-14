FROM neurodebian:nd18.04-non-free

# Git commit from which to build MRtrix3.
ARG MRTRIX3_GIT_COMMITISH="master"
# Command-line arguments for `./configure`
ARG MRTRIX_CONFIGURE_FLAGS=""
# Command-line arguments for `./build`
ARG MRTRIX_BUILD_FLAGS=""

# Prevent programs like `apt-get` from presenting interactive prompts.
ARG DEBIAN_FRONTEND="noninteractive"

# Install MRtrix3 compile-time dependencies.
RUN temp_deps='g++ git libeigen3-dev' \
    && apt-get -qq update \
    && apt-get install -yq --no-install-recommends \
          $temp_deps \
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
    && ./configure $MRTRIX_CONFIGURE_FLAGS \
    && ./build $MRTRIX_BUILD_FLAGS

# Install ANTs and FSL.
RUN apt-get -qq update \
    && apt-get install -yq --no-install-recommends \
          "ants=2.2.0-1ubuntu1" \
          ca-certificates \
          curl \
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

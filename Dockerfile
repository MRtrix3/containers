FROM MRtrix3:base

# Git commit from which to build MRtrix3
ARG MRTRIX3_GIT_COMMITISH="master"
# Command-line arguments for `./configure`
ARG MRTRIX3_CONFIGURE_FLAGS=""
# Command-line arguments for `./build`
ARG MRTRIX3_BUILD_FLAGS=""

# Dependencies for neurodocker
ARG NEURODOCKER_DEPS="bzip2 curl"
# Temporary dependencies that can be removed after build
ARG BUILD_TEMP_DEPS="g++ git"
ARG MRTRIX3_TEMP_DEPS="libeigen3-dev"
# Prevent programs like `apt-get` from presenting interactive prompts
ARG DEBIAN_FRONTEND="noninteractive"

ENV ANTSPATH="/opt/ants/bin/"
ENV ARTHOME="/opt/art"
ENV FREESURFER_HOME="/opt/freesurfer"
ENV FSLDIR="/opt/fsl"
ENV PATH="/opt/mrtrix3/bin:$ANTSPATH:$ARTHOME/bin:$FSLDIR/bin:$PATH"

# Perform removal of packages that were necessary for constructing the base container only
RUN apt-get remove --purge -y $NEURODOCKER_DEPS \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

# Clone, build, and install MRtrix3, and delete unnecessary components
WORKDIR /opt/mrtrix3
RUN git clone -b $MRTRIX3_GIT_COMMITISH --depth 1 https://github.com/MRtrix3/mrtrix3.git . \
    && ./configure $MRTRIX3_CONFIGURE_FLAGS \
    && ./build $MRTRIX3_BUILD_FLAGS \
    && rm -rf testing/ tmp/

# Do a system cleanup
RUN apt-get clean \
    && apt-get remove --purge -y $BUILD_TEMP_DEPS $MRTRIX3_TEMP_DEPS \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /work

ENTRYPOINT ["bash", "-c", "source /opt/fsl/etc/fslconf/fsl.sh && bash $@"]


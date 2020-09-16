FROM neurodebian:nd18.04-non-free

# Git commit from which to build MRtrix3.
ARG MRTRIX3_GIT_COMMITISH="master"
# Command-line arguments for `./configure`
ARG MRTRIX3_CONFIGURE_FLAGS=""
# Command-line arguments for `./build`
ARG MRTRIX3_BUILD_FLAGS=""
# Temporary dependencies that can be removed after MRtrix3 build
ARG MRTRIX3_TEMP_DEPS="g++ git libeigen3-dev"
# Temporary dependencies for other software packages
ARG OTHER_TEMP_DEPS="ca-certificates curl file python wget"

# Prevent programs like `apt-get` from presenting interactive prompts.
ARG DEBIAN_FRONTEND="noninteractive"

ENV FREESURFER_HOME="/opt/freesurfer"
ENV FSLDIR="/opt/fsl"
ENV PATH="/opt/mrtrix3/bin:/opt/fsl/bin:/usr/lib/ants:$PATH"

# Install MRtrix3 compile-time dependencies.
RUN apt-get -qq update \
    && apt-get install -yq --no-install-recommends \
          $MRTRIX3_TEMP_DEPS \
          $OTHER_TEMP_DEPS \
          dc \
          libfftw3-dev \
          libgl1-mesa-dev \
          libpng-dev \
          libqt5opengl5-dev \
          libqt5svg5-dev \
          libtiff5-dev \
          python3 \
          python3-distutils \
          qt5-default \
          zlib1g-dev

# Clone, build, and install MRtrix3.
WORKDIR /opt/mrtrix3
RUN git clone -b ${MRTRIX3_GIT_COMMITISH} --depth 1 https://github.com/MRtrix3/mrtrix3.git . \
    && ./configure $MRTRIX3_CONFIGURE_FLAGS \
    && ./build $MRTRIX3_BUILD_FLAGS \
    && apt-get remove --purge -y $MRTRIX3_TEMP_DEPS \
    && apt-get autoremove -y
WORKDIR /

# Install ANTs.
RUN apt-get -qq update \
    && apt-get install -yq --no-install-recommends "ants=2.2.0-1ubuntu1"

# Install FreeSurfer LUT
WORKDIR /opt/freesurfer
RUN wget -q https://raw.githubusercontent.com/freesurfer/freesurfer/v7.1.1/distribution/FreeSurferColorLUT.txt

# Install FSL.
RUN wget -q http://fsl.fmrib.ox.ac.uk/fsldownloads/fslinstaller.py -O /fslinstaller.py \
    && chmod 775 /fslinstaller.py \
    && python2 /fslinstaller.py -d /opt/fsl -V 6.0.4 -q \
    && rm -f /fslinstaller.py \
    && ( which immv || ( echo "FSLPython not properly configured; re-running" && rm -rf /opt/fsl/fslpython && /opt/fsl/etc/fslconf/fslpython_install.sh -f /opt/fsl || ( cat /tmp/fslpython*/fslpython_miniconda_installer.log && exit 1 ) ) )

# Do a system cleanup.
RUN apt-get clean \
    && apt-get remove --purge -y $OTHER_TEMP_DEPS \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

# Set up to use Python3
RUN ln -s /usr/bin/python3 /usr/bin/python

WORKDIR /work

ENTRYPOINT ["bash", "-c", "source /opt/fsl/etc/fslconf/fsl.sh && bash $@"]

ARG MAKE_JOBS="1"
ARG DEBIAN_FRONTEND="noninteractive"

FROM buildpack-deps:buster AS base-builder

FROM base-builder AS mrtrix3-builder

# Number of processors to use when building MRtrix3.
ARG MAKE_JOBS
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
WORKDIR /opt/mrtrix3
RUN git clone -b ${MRTRIX3_GIT_COMMITISH} --depth 1 https://github.com/MRtrix3/mrtrix3.git . \
    && ./configure $MRTRIX3_CONFIGURE_FLAGS \
    && NUMBER_OF_PROCESSORS=$MAKE_JOBS ./build $MRTRIX3_BUILD_FLAGS
RUN rm -rf tmp

# Download ANTs.
FROM base-builder as ants-installer
WORKDIR /opt/ants
RUN curl -fsSL https://dl.dropbox.com/s/fcdc9qg9jk0gbtw/ants-v0.tar.gz \
    | tar xz --strip-components 1

# Download FreeSurfer files.
FROM base-builder as freesurfer-installer
WORKDIR /opt/freesurfer
RUN curl -fsSLO https://raw.githubusercontent.com/freesurfer/freesurfer/v7.1.1/distribution/FreeSurferColorLUT.txt

# Download FSL.
FROM base-builder as fsl-installer
WORKDIR /opt/fsl
RUN curl -fsSL https://dl.dropbox.com/s/p5jftiicz43p6tt/fsl-v0.tar.gz \
    | tar xz --strip-components 1

# Build final image.
FROM python:3.8-slim AS final

# Install runtime system dependencies.
RUN apt-get -qq update \
    && apt-get install -yq --no-install-recommends \
        libfftw3-3 \
        libgl1-mesa-glx \
        libgomp1 \
        libqt5core5a \
        libqt5gui5 \
        libqt5network5 \
        libqt5widgets5 \
        libquadmath0 \
        libtiff5 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=ants-installer /opt/ants /opt/ants
COPY --from=freesurfer-installer /opt/freesurfer /opt/freesurfer
COPY --from=fsl-installer /opt/fsl /opt/fsl
COPY --from=mrtrix3-builder /opt/mrtrix3 /opt/mrtrix3

ENV FREESURFER_HOME="/opt/freesurfer" \
    LD_LIBRARY_PATH="/opt/fsl/lib:$LD_LIBRARY_PATH" \
    PATH="/opt/mrtrix3/bin:/opt/ants/bin:/opt/fsl/bin:$PATH"

WORKDIR /work
CMD ["/bin/bash"]

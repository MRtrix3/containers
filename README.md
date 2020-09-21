# Containers for MRtrix3

Hosts Dockerfiles to build MRtrix3 containers

## Compression

Following are instructions for utilising `neurodocker reprozip trace` command to minimise the size of the resulting Docker image.

1. Constructing base image:

    1.  Install the `docker` and `neurodocker` Python packages:
        `pip install docker neurodocker`
    
    1.  Download the ACPCdetect tool from NITRC into the working directory:
        https://www.nitrc.org/frs/download.php/10595/acpcdetect_v2.0_LinuxCentOS6.7.tar.gz

    1.  Build a Docker container utilising the `Dockerfile_base` recipe contained in this repository; here the name `mrtrix3_preminify:latest` is used:
        `docker build - -f Dockerfile_base -t mrtrix3_preminify:latest`

    1.  From the root directory of a clone of this repository, download a copy of the *MRtrix3* "`script_test_data`" repository, and unzip in-place, leading to a new filled directory "`script_test_data-master/`":
        `wget https://github.com/MRtrix3/script_test_data/archive/master.zip && unzip master.zip`

    1.  Set the container running with the necessary settings:
        `docker run --rm -itd --name mrtrix3_minify --security-opt=seccomp:unconfined --volume $(pwd)/script_test_data-master:/mnt mrtrix3_preminify:latest`

    1.  Instruct the container to run the requisite tests to identify and remove unused external software dependencies:
        `neurodocker-minify --container mrtrix3_minify -d /opt/ants /opt/art /opt/fsl /entrypoint.sh`

    1.  Create a new image from the minified container:
        `docker export mrtrix3_minify | docker import - mrtrix3_base`

    1.  Tag and upload this image to DockerHub:
        ```
        docker tag mrtrix3_base mrtrix3/base:#.#.#
        docker login
        docker push mrtrix3/base:#.#.#
        ```
        (Replace "#.#.#" with appropriate tag for MRtrix3 base container)

1. Constructing main image:

    1.  Build using the `Dockerfile` recipe contained in this repository:
        `docker build . -t mrtrix3`

    1.  Tag and upload this image to DockerHub:
        ```
        docker tag mrtrix3 mrtrrx3/mrtrix3:#.#.#
        docker login
        docker push mrtrix3/mrtrix3:#.#.#
        ```
        (Replace "#.#.#" with corresponding MRtrix3 version tag)


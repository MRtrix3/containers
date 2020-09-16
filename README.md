# Containers for MRtrix3

Hosts Dockerfiles to build MRtrix3 containers

## Compression

Following are instructions for utilising `neurodocker reprozip trace` command to minimise the size of the resulting Docker container.

1.  Install `neurodocker` via `pip`

1.  Build a Docker container utilising the `Dockerfile` recipe contained in this repository; here the name `mrtrix3_bloated:latest` is used:
    `docker build . -t mrtrix3_bloated:latest`

1.  From the root directory of a clone of this repository, download a copy of the *MRtrix3* "`script_test_data`" repository, and unzip in-place, leading to a new filled directory "`script_test_data-master/`":
    `wget https://github.com/MRtrix3/script_test_data/archive/master.zip && unzip master.zip`

1.  Set the container running with the necessary settings:
    `docker run --rm -itd --name mrtrix3_minify --security-opt=seccomp:unconfined --volume $(pwd)/script_test_data-master:/mnt mrtrix3_bloated:latest`

1.  Instruct the container to run the requisite tests to identify and remove unused external software dependencies:
    `neurodocker-minify --container mrtrix3_minify -d /opt/ants /opt/fsl --commands "/tests.sh"`

1.  Create a new image from the minified container:
    `docker export mrtrix3_minify | docker import - mrtrix3:latest`


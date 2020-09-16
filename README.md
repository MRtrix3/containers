# Containers for MRtrix3

Hosts Dockerfiles to build MRtrix3 containers

## Compression

Following are instructions for utilising `neurodocker reprozip trace` command to minimise the size of the resulting Docker container.

1.  Build a Docker container utilising the `Dockerfile` recipe contained in this repository; here the name `mrtrix3:latest` is used.

1.  From the root directory of a clone of this repository, download a copy of the *MRtrix3* "`script_test_data`" repository, and unzip in-place, leading to a new filled directory "`script_test_data-master/`".

1.  Set the container running with the necessary settings:
    `docker run --rm -itd --name mrtrix3_minify_test --security-opt=seccomp:unconfined --volume $(pwd)/script_test_data-master:/mnt mrtrix3:latest`

1.  Instruct the container to run the requisite tests to capture external software dependencies:
    `neurodocker reprozip trace mrtrix3_minify_test -d /opt/fsl --commands "/tests.sh"`

***TBC***

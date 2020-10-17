# Containers for *MRtrix3*

Hosts Dockerfiles to build *MRtrix3* containers

## Users: Run terminal command

```
docker run --rm -it mrtrix3 <command>
```

If not built locally, `docker` will download the latest image from DockerHub.

## Users: Run GUI

These instructions are for Linux.

```
xhost +local:root
docker run --rm -it -v /tmp/.X11-unix:/tmp/.X11-unix -e DISPLAY=$DISPLAY mrtrix3 mrview
xhost -local:root  # Run this when finished.
```

## Users: Locally build Docker image

```
docker build --tag mrtrix3 .
```

Set `DOCKER_BUILDKIT=1` to build parts of the Docker image in parallel, which can speed up build time.
Use `--build-arg MAKE_JOBS=4` to build *MRtrix3* with 4 processors (can substitute this with any number of processors > 0); if omitted, *MRtrix3* will be built using a single thread only.

-----

## Developers: Update minified external dependencies

This process can only be completed by those with write access to the ["*MRtrix3* container dependencies" OSF project](https://osf.io/5rwp3/).
These files contain "minified" versions of external neuroimaging software package dependencies, containing only those components that are utilised by *MRtrix3* scripts.
These files should only need to be updated if:

-   An *MRtrix3* update introduces a new feature that invokes some new external software tool not previously utilised;
-   A requisite update occurs in one of these external softwares.

1.  Install the `docker` and `neurodocker` Python packages.

    ````
    pip install docker neurodocker
    ````

2.  Download the ART ACPCdetect tool from NITRC into the working directory.

    This cannot be downloaded directly via e.g. `wget`, as it requires logging in to NITRC; instead, visit the following link with a web browser:
    [`https://www.nitrc.org/frs/download.php/10595/acpcdetect_v2.0_LinuxCentOS6.7.tar.gz`](https://www.nitrc.org/frs/download.php/10595/acpcdetect_v2.0_LinuxCentOS6.7.tar.gz)

3. Download test data necessary for minification process.

    ```
    curl -fL -# https://github.com/MRtrix3/script_test_data/archive/master.tar.gz | tar xz
    ```

4. Update file `minify.Dockerfile` to install the desired versions of external software packages.

5. Build Docker image for `neurodocker-minify`, with complete installations of external packages.

    ```
    DOCKER_BUILDKIT=1 docker build --tag mrtrix3:minify --file minify.Dockerfile --build-arg MAKE_JOBS=4 .
    ```

    `DOCKER_BUILDKIT=1` enables BuildKit, which builds separate build stages in parallel.
    This can speed up Docker build times in some circumstances.
    In this case, ANTs and *MRtrix3* will be compiled in parallel, and other downloads will be performed at the same time as well.

    The `MAKE_JOBS` argument controls how many cores are used for compilation of ANTs and *MRtrix3*.
    If BuildKit is utilised, do not specify all of the available threads; specify half or fewer, so that threads are not unnecessarily split across jobs and RAM usage is not excessive.

6. Create a minified version of the Docker image.

    ```
    docker run --rm -itd --name mrtrix3 --security-opt=seccomp:unconfined --volume $(pwd)/script_test_data-master:/mnt mrtrix3:minify
    neurodocker-minify --dirs-to-prune /opt --container mrtrix3 --commands "bash cmds-to-minify.sh"
    docker export mrtrix3 | docker import - mrtrix3:minified
    docker stop mrtrix3
    ```

7. Generate tarballs for each of the utilised dependencies.

    ```
    mkdir -p tarballs
    docker run --rm -itd --workdir /opt --name mrtrix3 \
        --volume $(pwd)/tarballs:/output mrtrix3:minified bash
    docker exec mrtrix3 bash -c "tar c art | pigz -9 > /output/acpcdetect_<version>.tar.gz"
    docker exec mrtrix3 bash -c "tar c ants | pigz -9 > /output/ants_<version>.tar.gz"
    docker exec mrtrix3 bash -c "tar c fsl | pigz -9 > /output/fsl_<version>.tar.gz"
    docker stop mrtrix3
    ```

    For each tarball, manually replace text "`<version>`" with the version number of that particular software that was installed in the container.

7.  Upload these files to [OSF](https://osf.io/nfx85/).

File `Dockerfile` can then be modified to download the desired versions of external software packages.
As OSF file download links do not contain file names, which would otherwise indicate the version of each software to be downloaded, please ensure that comments within that file are updated to indicate the version of that software within the tarball.


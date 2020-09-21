# Containers for MRtrix3

Hosts Dockerfiles to build MRtrix3 containers

## Build Docker image

```
docker build --tag mrtrix3 .
```

Set `DOCKER_BUILDKIT=1` to build parts of the Docker image in parallel and greatly speed up build time. Use `--build-arg MAKE_JOBS=4` to build MRtrix3 with 4 processors. Substitute this with any number of processors > 0.

## Run GUI

These instructions are for Linux.

```
xhost +local:root
docker run --rm -it -v /tmp/.X11-unix:/tmp/.X11-unix -e DISPLAY=$DISPLAY mrtrix3 mrview
xhost -local:root  # Run this when finished.
```

## Update minified ANTs and FSL installations

1. Build full Docker image, with complete ANTs and FSL installations

    This step should be run very infrequently. The full image is only necessary to create the slim installations of ANTs and FSL, which are used in the slim Docker image. If mrtrix3 programs in the future require other parts of ANTs or FSL (or other software), then the full image will have to be rebuilt, and the slim installations of ANTs and FSL will have to be re-uploaded online.

    ```
    DOCKER_BUILDKIT=1 docker build --tag mrtrix3:full --file full.Dockerfile --build-arg MAKE_JOBS=2 .
    ```

    `DOCKER_BUILDKIT=1` enables BuildKit, which builds separate build stages in parallel. This can greatly speed up Docker build times. In this case, ANTs and MRtrix3 will be compiled in parallel, and FSL will be downloaded at the same time as well.

    The `MAKE_JOBS` argument controls how many cores are used for compilation of ANTs and MRtrix3. Because both packages are build in parallel, do not specify all of the available cores. Specify fewer than half, so at least one core is available for downloading FSL.

2. Create a minified version of the Docker image.

    - Download test data

    ```
    curl -fL -# https://github.com/MRtrix3/script_test_data/archive/master.tar.gz | tar xz
    ```

    ```
    docker run --rm -itd --name mrtrix3 --security-opt=seccomp:unconfined --volume $(pwd)/script_test_data-master:/mnt mrtrix3:full
    neurodocker-minify --dirs-to-prune /opt --container mrtrix3 --commands "bash cmds-to-minify.sh"
    docker export mrtrix3 | docker import - mrtrix3:minified-ants-fsl
    docker stop mrtrix3
    ```

    - Extract `/opt/ants` and `/opt/fsl` from the image, bundle them into two `.tar.gz` files, and upload somewhere.

    ```
    mkdir -p slim-installs
    docker run --rm -itd --workdir /opt --name mrtrix3 \
        --volume $(pwd)/slim-installs:/output mrtrix3:minified-ants-fsl bash
    # Install pigz for multi-core gzip compression.
    docker exec mrtrix3 bash -c "apt-get update && apt-get install --yes pigz"
    docker exec mrtrix3 bash -c "tar c ants | pigz -9 > /output/ants.tar.gz"
    docker exec mrtrix3 bash -c "tar c fsl | pigz -9 > /output/fsl.tar.gz"
    docker stop mrtrix3
    ```

3. Build Docker image

    ```
    DOCKER_BUILDKIT=1 docker build --tag mrtrix3 --build-arg MAKE_JOBS=6 .
    ```

    In this Dockerfile, the only software being compiled is MRtrix3, so all (or most) CPU cores can be used for the build. The minified parts of ANTs and FSL are downloaded from the web.

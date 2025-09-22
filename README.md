# docker-builds

This repository contains scripts and GitHub Actions to build Docker images from multiple Dockerfiles. It organizes builds using a common base image, versioning, and shared build scripts (placed in the rootfs folder). If necessary, Dockerfiles and code can be cloned from remote repositories.

## Usage

To build an image, run the `build.sh` script with the name of the image as the first argument:

```bash
./builders/ubi/build.sh <image-name>
```

For example, to build the `ubi` image, you would run:

```bash
./builders/ubi/build.sh ubi
```

## Contact

If you have any questions or issues, please contact the DevOps team at devops@example.com.

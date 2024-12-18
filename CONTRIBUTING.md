# Developer Notes

## `texlive` install hangs

The GitHub Actions workflow first job (`foundation`) installs the `base` target of the Docker image. This step installs `texlive` and on the GitHub Actions `ubuntu-latest` runners this can take a long time or just fail in general. If this happens, run `make test/base-r-notebook` to build and test the `base-r-notebook` image (it could be any image, but this is the smallest). This will cache the `base` target to the registry and the GitHub Action can skip building it.

# CourseKata Docker Stacks

[![base-r-notebook](https://img.shields.io/docker/image-size/coursekata/base-r-notebook/latest?label=base-r-notebook)](https://ghcr.io/coursekata/base-r-notebook) [![essentials-notebook](https://img.shields.io/docker/image-size/coursekata/essentials-notebook/latest?label=essentials-notebook)](https://ghcr.io/coursekata/essentials-notebook) [![r-notebook](https://img.shields.io/docker/image-size/coursekata/r-notebook/latest?label=r-notebook)](https://ghcr.io/coursekata/r-notebook) [![datascience-notebook](https://img.shields.io/docker/image-size/coursekata/datascience-notebook/latest?label=datascience-notebook)](https://ghcr.io/coursekata/datascience-notebook) [![datascience-core](https://img.shields.io/docker/image-size/coursekata/datascience-core/latest?label=datascience-core)](https://ghcr.io/coursekata/datascience-core) [![exercises-notebook](https://img.shields.io/docker/image-size/coursekata/exercises-notebook/latest?label=exercises-notebook)](https://ghcr.io/coursekata/exercises-notebook)

This is a collection of Docker images published for different purposes.. Read the [Contents](#contents) section for a description of what is in each image. Additionally, each of the images has a tag indicating something about how the image was built. Read the [Tagging](#tagging) section to get an idea of how the images are built and what the tags mean.

You will eventually need a link structured as [Contents](#contents):[Tag](#tagging).

For example, in this link `coursekata/essentials-notebook:latest`, the `essentials-notebook` is an example of [Contents](#contents) and `latest` is an example of a [Tag](#tagging).

## Contents

There are six images published from this repository. Four form a ladder — each contains everything in the one before it, package for package, though they are not literally built on top of one another (one `Dockerfile`, one build per image). Two more exist for specific consumers and sit outside the ladder. Both ARM64- and AMD64-compatible images are built for each of these. Both ARM64- and AMD64-compatible images are built for each of these.

- [base-r-notebook](https://ghcr.io/coursekata/base-r-notebook): an image with Python and R installed, and that's it. R is configured to be the default notebook, but both R and Python notebooks are supported. This is a good image to use if you are building your own image from scratch.
- [essentials-notebook](https://ghcr.io/coursekata/essentials-notebook): an image with all of the R packages used in CourseKata books and CourseKata's curated Jupyter Notebooks. If you are coming from the CourseKata book this is a great starting place: you will be able to do everything you did in the books and more!
- [r-notebook](https://ghcr.io/coursekata/r-notebook): this image has all of the contents of the _essentials-notebook_ with the addition of other R packages that instructors have requested that we install for data science and statistics.
- If you have a specific package you think would be useful to install here, please [submit an issue describing your use case](https://github.com/coursekata/docker-stacks/issues).
- [datascience-notebook](https://ghcr.io/coursekata/datascience-notebook): this image builds on _r-notebook_ by adding a variety of R and Python packages for data science and statistics.
- If you have a specific package you think would be useful to install here, please [submit an issue describing your use-case](https://github.com/coursekata/docker-stacks/issues).
- [datascience-core](https://ghcr.io/coursekata/datascience-core): everything in _datascience-notebook_ except the Jupyter front end (JupyterLab, classic Notebook, `jupyterhub-singleuser`). Meant for embedding under a different notebook server, not for running directly — if you're not sure you need this one, you don't.
- [exercises-notebook](https://ghcr.io/coursekata/exercises-notebook): _essentials-notebook_ plus the exercise-checking machinery (`pythonwhat`, `testwhat`) that grades the CourseKata books' inline exercises. Not part of the ladder above, and not meant for general use — it exists to run book exercises.

An image's R packages are the union of the [`r/<feature>.txt`](r/) files named by its environment's `features` list in [`pixi.toml`](pixi.toml).

### `next/*` is not a product

You may see a `ghcr.io/coursekata/next/<image>` namespace in this organization's GHCR packages. It holds weekly build candidates used internally before a release is promoted. It carries no compatibility promise, nothing here ever tells you to pull it, and no tag in it is stable. If you're choosing what to run, everything on this page is about the six images above — `next/*` isn't one of them.

### Installing R Packages Locally

If you want to install the same R packages on your local machine (without using Docker), generate the ref list for your desired image and install it with pak:

```sh
python3 scripts/get-refs.py essentials-notebook > refs.txt
Rscript -e 'pak::pkg_install(readLines("refs.txt"))'
```

Each build also produces a version-pinned `r-<image>.txt` with the exact resolved versions, installable the same way; it will be attached to releases once the release contract mentioned below lands.

## Tagging

**This section is being replaced and does not describe the current build.** The weekly build now publishes only to the `next/*` namespace above — not to the six repositories this page covers — and none of the `sha-`, dated, or "most recent stable" behavior below is currently produced. A release contract describing what the six images above actually promise, and how they're tagged, is coming; until then, treat the rest of this section as historical.

These images are built based on a variety of triggers, and each trigger results in a different tag. You will notice that some issues have multiple tags, this is because the tags are there to either help you keep up-to-date, or pin your image to a specific revision or timepoint. This section is structured based on why you might choose one tag compared to another.

### You want all the updates and changes

If you want all the updates and changes to these images as we make them, you can use the `latest` tag. This will be the most recently built, stable version of each image. Note that while we try our best to maintain stability in terms of the packages that are installed on each image, by definition images tagged `latest` will be subject to changes as we improve our structure and delivery.

### You mostly want stability

Though we try to maintain stability in our installed packages and libraries, there is the chance that one may be removed. If you want to ensure that you continue to get the same packages, but that they are update weekly, you can select an image that is tagged with a specific repository revision, e.g `sha-bf50210`. Images with a specific revision tag will always have been built from the repository state at the time of that revision, so they will always have the same version of Python and R, and the package lists will always be the same.

A downside of this approach is that when we update this repository, that particular revision will no longer be rebuilt. Before we make any commits to the repository, it will get weekly updates to packages, but after that it will be locked in place and not updated further.

### You want to control your updates in full

If you need your images to be highly reproducible, e.g. for use in systems where the image stability is critical, you will likely want to make sure that the image does not change at all when you pull. There are two ways to do this:

1. Use the full SHA digest of the image
2. Use a dated tag: all of these images are built weekly (Monday starting at 3:00 UTC), so you will see many tags like `2023-04-21` indicating when they were built

Using one of these two methods will ensure that the image will be the same everytime you pull it.

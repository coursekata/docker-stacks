# CourseKata Docker Stacks

[![base-r-notebook](https://img.shields.io/docker/image-size/coursekata/base-r-notebook/latest?label=base-r-notebook)](https://ghcr.io/coursekata/base-r-notebook)
[![essentials-notebook](https://img.shields.io/docker/image-size/coursekata/essentials-notebook/latest?label=essentials-notebook)](https://ghcr.io/coursekata/essentials-notebook)
[![r-notebook](https://img.shields.io/docker/image-size/coursekata/r-notebook/latest?label=r-notebook)](https://ghcr.io/coursekata/r-notebook)
[![datascience-notebook](https://img.shields.io/docker/image-size/coursekata/datascience-notebook/latest?label=datascience-notebook)](https://ghcr.io/coursekata/datascience-notebook)

This is a collection of Docker images that build on one another for different purposes. Read the [Contents](#contents) section for a description of what is in each image. Additionally, each of the images has a tag indicating something about how the image was built. Read the [Tagging](#tagging) section to get an idea of how the images are built and what the tags mean.

You will eventually need a link structured as [Contents](#contents):[Tag](#tagging).

For example, in this link `coursekata/essentials-notebook:latest`, the `essentials-notebook` is an example of [Contents](#contents) and `latest` is an example of a [Tag](#tagging).

## Contents

There are currently four different images that you can choose from, as listed below. Each successive image builds on the one before it and contains everything in the previous image. Both ARM64- and AMD64-compatible images are built for each of these.

- [base-r-notebook](https://ghcr.io/coursekata/base-r-notebook): an image with Python and R installed, and that's it. R is configured to be the default notebook, but both R and Python notebooks are supported. There are no other packages installed on this image. This is a good image to use if you are building your own image from scratch.
- [essentials-notebook](https://ghcr.io/coursekata/essentials-notebook): an image with all of the R packages used in CourseKata books and CourseKata Jupyter Notebooks. If you are coming from the CourseKata book this is a great starting place: you will be able to do everything you did in the books and more!
  - You can see specifically what packages are installed by looking at [essentials-notebook/requirements.r](essentials-notebook/requirements.r).
- [r-notebook](https://ghcr.io/coursekata/r-notebook): this image has all of the contents of the _essentials-notebook_ with the addition of other R packages that instructors have requested that we install for data science and statistics.
  - You can see specifically what packages are installed by looking at [r-notebook/requirements.r](r-notebook/requirements.r)
  - If you have a specific package you think would be useful to install here, please [submit an issue describing your use case](https://github.com/coursekata/docker-stacks/issues).
- [datascience-notebook](https://ghcr.io/coursekata/datascience-notebook): this image builds on _r-notebook_ by adding a variety of Python packages for data science and statistics.
  - You can see specifically what packages are installed by looking at [datascience-notebook/requirements.r](datascience-notebook/requirements.r) and [datascience-notebook/requirements.txt](datascience-notebook/requirements.txt)
  - If you have a specific package you think would be useful to install here, please [submit an issue describing your use case](https://github.com/coursekata/docker-stacks/issues).

## Tagging

These images are built based on a variety of triggers, and each trigger results in a different tag. You will notice that some issues have multiple tags, this is because the tags are there to either help you keep up-to-date, or pin your image to a specific revision or timepoint. This section is structured based on why you might choose one tag compared to another.

### You want all the updates and changes

If you want all the updates and changes to these images as we make them, you can use the `latest` tag. This will be the most recently built, stable version of each image. Note that while we try our best to maintain stability in terms of the packages that are installed on each image, by definition images tagged `latest` will be subject to changes as we improve our structure and delivery.

### You mostly want stability

Though we try to maintain stability in our installed packages and libraries, there is the chance that one may be removed. If you want to ensure that you continue to get the same packages, but that they are update weekly, you can select an image that is tagged with a specific repository revision, e.g `sha-bf50210`. Images with a specific revision tag will always have been built from the repository state at the time of that revision, so they will always have the same version of Python and R, and the package lists will always be the same.

A downside of this approach is that when we update this repository, that particular revision will no longer be rebuilt. Before we make any commits to the repository, it will get weekly updates to packages, but after that it will be locked in place and not updated further.

### You want to control your updates in full

If you need your images to be highly reproducible, e.g. for use in systems where the image stability is critical, you will likely want to make sure that the image does not change at all when you pull. There are two ways to do this:

1. Use the full SHA digest of the image
2. Use a dated tag: all of these images are built twice a week (Tuesday and Friday starting at 1:00 UTC), so you will see many tags like `2023-04-21` indicating when they were built

Using one of these two methods will ensure that the image will be the same everytime you pull it.

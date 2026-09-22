# CourseKata Docker Stacks

[base-r-notebook](https://ghcr.io/coursekata/base-r-notebook) [essentials-notebook](https://ghcr.io/coursekata/essentials-notebook) [r-notebook](https://ghcr.io/coursekata/r-notebook) [datascience-notebook](https://ghcr.io/coursekata/datascience-notebook) [datascience-core](https://ghcr.io/coursekata/datascience-core) [exercises-notebook](https://ghcr.io/coursekata/exercises-notebook)

This repository publishes six Docker images for CourseKata notebooks and related services. [Contents](#contents) describes what each image contains; [Tagging](#tagging) describes the stability guarantees attached to its tags.

Pull an image as `ghcr.io/coursekata/<image>:<tag>`. For example, `ghcr.io/coursekata/essentials-notebook:latest` selects the essentials image and its latest promoted release.

## Contents

There are six images published from this repository. Four form a ladder: each contains everything in the one before it, package for package, though they are not literally built on top of one another (one `Dockerfile`, one build per image). Two more exist for specific consumers and sit outside the ladder. Every image supports AMD64 and ARM64.

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

Each stable environment release includes version-pinned R package records for both architectures. They are attached to the corresponding GitHub release.

## Tagging

The six product repositories have two kinds of tags:

- `latest` points to the most recently promoted environment release. It moves when a new release is promoted.
- `YYYY-MM-DD` identifies one promoted environment release by the UTC completion date of its candidate build. The promotion workflow refuses to replace a dated tag with a different digest.

Use a full `sha256:` digest when the deployment itself must be content-addressed. A dated tag is also stable, but a digest states the exact bytes without a registry lookup.

The weekly build publishes candidates under `ghcr.io/coursekata/next/`. A candidate reaches the six product repositories only after all six images pass on AMD64 and ARM64 and the promotion workflow verifies that they came from the selected successful `main` run. Promotion copies the tested image indexes; it does not rebuild them. It writes and verifies every dated tag before changing any `latest` tag.

Each promotion creates a GitHub release named `environment-YYYY-MM-DD`. Its manifest records the source run, commit, image digests, platform digests, and previous `latest` digests. The release also contains the exact R package inventory for each image and architecture.

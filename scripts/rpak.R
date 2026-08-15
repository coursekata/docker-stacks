#!/usr/bin/env Rscript

#' CourseKata R package tooling
#'
#' Reads rpixi.toml (the source of truth for R packages) and generates
#' self-contained installer scripts under pak-scripts/.
#'
#' The generated scripts are what the Docker build runs. They depend on nothing
#' but pak, which is deliberate: the image no longer needs a TOML parser or an
#' argument parser just to install R packages, and conda no longer needs to ship
#' any r-* package. That is what lets r-base move to 4.6, where conda-forge has
#' no r-* builds at all.
#'
#' Commands:
#'   list <env>     print the pak refs for an environment, one per line
#'   pakgen         regenerate pak-scripts/*.R for every environment
#'   validate       check the manifest parses and every ref is well-formed

# RcppTOML cannot come from conda any more: pixi.toml deliberately carries no
# r-* packages, because a single one pins the shared solve-group below R 4.6.
# So this dev-side tool bootstraps its own parser on first use.
if (!requireNamespace("RcppTOML", quietly = TRUE)) {
  message("rpak: installing RcppTOML (one-time, needed to read rpixi.toml)")
  repos <- getOption("repos")
  if (is.null(repos[["CRAN"]]) || !nzchar(repos[["CRAN"]]) || repos[["CRAN"]] == "@CRAN@") {
    options(repos = c(CRAN = "https://cloud.r-project.org"))
  }
  ok <- tryCatch({
    if (requireNamespace("pak", quietly = TRUE)) {
      pak::pkg_install("RcppTOML", ask = FALSE)
    } else {
      utils::install.packages("RcppTOML")
    }
    requireNamespace("RcppTOML", quietly = TRUE)
  }, error = function(e) FALSE)
  if (!ok) {
    stop("rpak: RcppTOML is required and could not be installed automatically.\n",
         "  Install it by hand:  Rscript -e 'install.packages(\"RcppTOML\")'",
         call. = FALSE)
  }
}

suppressPackageStartupMessages({
  library(RcppTOML)
})

MANIFEST <- Sys.getenv("RPIXI_MANIFEST", "rpixi.toml")
OUTDIR <- "pak-scripts"

# --------------------------------------------------------------------------
# Manifest
# --------------------------------------------------------------------------

read_manifest <- function(path = MANIFEST) {
  if (!file.exists(path)) stop("manifest not found: ", path, call. = FALSE)
  RcppTOML::parseTOML(path)
}

#' Packages for an environment = base dependencies + each of its features
env_packages <- function(manifest, env) {
  envs <- manifest$environments
  if (is.null(envs[[env]])) {
    stop("unknown environment: ", env,
         " (have: ", paste(names(envs), collapse = ", "), ")", call. = FALSE)
  }
  out <- manifest$dependencies %||% list()
  for (f in envs[[env]]$features %||% character()) {
    feat <- manifest$feature[[f]]$dependencies
    if (is.null(feat)) stop("environment ", env, " names unknown feature: ", f, call. = FALSE)
    out <- utils::modifyList(out, feat)
  }
  out
}

`%||%` <- function(x, y) if (is.null(x)) y else x

# --------------------------------------------------------------------------
# Refs
# --------------------------------------------------------------------------

#' Convert one manifest entry into a pak ref plus any custom repo it needs.
#'
#' A bare string ("*" or a version) means CRAN. Versions are informational:
#' pak resolves to current, matching the previous behaviour.
SPEC_KEYS <- c("github", "tag", "repos", "force")

as_ref <- function(name, spec) {
  repo <- NULL

  if (is.list(spec)) {
    unknown <- setdiff(names(spec), SPEC_KEYS)
    if (length(unknown)) {
      stop(sprintf(
        "%s: unknown spec key(s): %s\n  For the package \"%s.%s\", quote the key: \"%s.%s\" = \"*\"",
        name, paste(unknown, collapse = ", "), name, unknown[1], name, unknown[1]
      ), call. = FALSE)
    }
  }

  if (is.character(spec)) {
    ref <- name
  } else if (!is.null(spec$github)) {
    ref <- spec$github
    if (!is.null(spec$tag)) ref <- paste0(ref, "@", spec$tag)
  } else {
    ref <- name
    repo <- spec$repos
  }

  # force = reinstall even when already present
  if (is.list(spec) && isTRUE(spec$force)) ref <- paste0(ref, "?reinstall")

  list(ref = ref, repo = repo)
}

env_refs <- function(manifest, env) {
  pkgs <- env_packages(manifest, env)
  lapply(names(pkgs), function(n) as_ref(n, pkgs[[n]]))
}

# --------------------------------------------------------------------------
# Generation
# --------------------------------------------------------------------------

render_script <- function(env, refs) {
  repos <- unique(Filter(Negate(is.null), lapply(refs, `[[`, "repo")))
  all_refs <- vapply(refs, `[[`, character(1), "ref")

  repo_lines <- if (length(repos)) {
    c(
      "# Custom repositories must be configured BEFORE resolution, not after.",
      "# Packages outside CRAN (cmdstanr) and packages that depend on them",
      "# (rethinking) are resolved in the same pass, so a repo added afterwards",
      "# is too late and the whole solve fails.",
      sprintf(
        "options(repos = c(getOption(\"repos\"), %s))",
        paste(sprintf("\"%s\"", repos), collapse = ", ")
      ),
      ""
    )
  } else {
    character()
  }

  c(
    "#!/usr/bin/env Rscript",
    "",
    sprintf("# R packages for the %s image.", env),
    "#",
    "# GENERATED by scripts/rpak.R from rpixi.toml — do not edit by hand.",
    "# Regenerate with: Rscript scripts/rpak.R pakgen",
    "#",
    "# Self-contained on purpose: the only thing this needs is pak, so the image",
    "# does not have to ship a TOML parser or any conda r-* package.",
    "",
    "options(warn = 2)  # a failed install must fail the build, not warn",
    "",
    "if (!requireNamespace(\"pak\", quietly = TRUE)) {",
    "  # Prefer the prebuilt binary; fall back to CRAN source.",
    "  ok <- tryCatch({",
    "    install.packages(\"pak\", repos = sprintf(",
    "      \"https://r-lib.github.io/p/pak/stable/%s/%s/%s\",",
    "      .Platform$pkgType, R.Version()$os, R.Version()$arch))",
    "    requireNamespace(\"pak\", quietly = TRUE)",
    "  }, error = function(e) FALSE)",
    "  if (!ok) install.packages(\"pak\", repos = \"https://cloud.r-project.org\")",
    "}",
    "",
    "options(",
    "  pkg.sysreqs = TRUE,",
    "  pkg.sysreqs_platform = \"ubuntu-24.04\"",
    ")",
    "",
    repo_lines,
    sprintf("message(\"Installing %d R packages for %s ...\")", length(all_refs), env),
    "pak::pkg_install(",
    "  c(",
    paste0("    ", sprintf("\"%s\"", all_refs), c(rep(",", length(all_refs) - 1), "")),
    "  ),",
    "  upgrade = FALSE,",
    "  ask = FALSE",
    ")",
    "",
    "message(\"R package installation complete.\")",
    ""
  )
}

cmd_pakgen <- function() {
  m <- read_manifest()
  dir.create(OUTDIR, showWarnings = FALSE)
  for (env in names(m$environments)) {
    refs <- env_refs(m, env)
    path <- file.path(OUTDIR, paste0(env, ".R"))
    writeLines(render_script(env, refs), path)
    Sys.chmod(path, "0755")

    names_path <- file.path(OUTDIR, paste0(env, ".packages.txt"))
    writeLines(names(env_packages(m, env)), names_path)

    cat(sprintf("wrote %-40s %3d packages\n", path, length(refs)))
  }
}

#' list <env> [--refs]
#'
#' Default output is package NAMES, which is what the test suite needs — it
#' loads each one with library(). Pak refs are a different thing: a GitHub ref
#' carries the repo, not the package, and "coursekata/coursekata-r" installs a
#' package called "coursekata". The manifest key is always the package name.
cmd_list <- function(env, as_refs = FALSE) {
  m <- read_manifest()
  out <- if (as_refs) {
    vapply(env_refs(m, env), `[[`, character(1), "ref")
  } else {
    names(env_packages(m, env))
  }
  writeLines(out)
}

cmd_validate <- function() {
  m <- read_manifest()
  problems <- character()
  for (env in names(m$environments)) {
    refs <- tryCatch(env_refs(m, env), error = function(e) {
      problems <<- c(problems, conditionMessage(e)); NULL
    })
    if (is.null(refs)) next
    for (r in refs) {
      if (!nzchar(r$ref)) problems <- c(problems, paste0(env, ": empty ref"))
      # A bare name with no repo must be resolvable from CRAN. coursekata is the
      # cautionary case: it is not on CRAN and only ever resolved because a conda
      # r-coursekata package was masking the broken ref.
      if (grepl("^[A-Za-z0-9.]+$", sub("\\?.*$", "", r$ref)) && is.null(r$repo)) next
    }
  }
  if (length(problems)) {
    cat("INVALID:\n", paste0(" - ", problems, collapse = "\n"), "\n", sep = "")
    quit(status = 1)
  }
  cat("manifest OK:", length(m$environments), "environments\n")
}

# --------------------------------------------------------------------------

args <- commandArgs(trailingOnly = TRUE)
cmd <- if (length(args)) args[1] else "help"

switch(cmd,
  pakgen = cmd_pakgen(),
  list = {
    if (length(args) < 2) stop("usage: rpak.R list <environment> [--refs]", call. = FALSE)
    cmd_list(args[2], as_refs = "--refs" %in% args)
  },
  validate = cmd_validate(),
  {
    cat("usage: rpak.R [pakgen | list <env> | validate]\n")
    quit(status = if (cmd == "help") 0 else 1)
  }
)

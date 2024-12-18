options(warn = 2)

make_env <- function(depends = c(), github = c(), cran = c(), force_cran = c()) {
  list(
    "depends" = unique(depends),
    "github" = unique(github),
    "cran" = unique(cran),
    "force_cran" = unique(force_cran)
  )
}

environments <- list(
  "base-r-notebook" = make_env(),
  "essentials-notebook" = make_env(
    depends = c("base-r"),
    force_cran = c("coursekata"),
    github = c(
      "coursekata/fivethirtyeightdata",
      "coursekata/Lock5withR",
      "coursekata/testwhat"
    ),
    cran = c(
      "coursekata",
      "fivethirtyeight",
      "ggpubr",
      "gridExtra",
      "lme4",
      "plotly",
      "statmod"
    )
  ),
  "r-notebook" = make_env(
    depends = c("essentials"),
    force_cran = c("V8"),
    github = c("mobilizingcs/mobilizr"),
    cran = c(
      "av",
      "bayesplot",
      "broom.mixed",
      "car",
      "dagitty",
      "datapasta",
      "DHARMa",
      "easystats",
      "emmeans",
      "gganimate",
      "ggdag",
      "ggeffects",
      "gifski",
      "gt",
      "gtsummary",
      "here",
      "janitor",
      "lmerTest",
      "loo",
      "mapdata",
      "mapproj",
      "marginaleffects",
      "neuralnet",
      "OCSdata",
      "posterior",
      "profvis",
      "psych",
      "RcppTOML",
      "reticulate",
      "simstudy",
      "sjPlot",
      "Stat2Data",
      "tidybayes",
      "tidymodels",
      "tidyverse"
    )
  ),
  "datascience-notebook" = make_env(
    depends = c("r"),
    cran = c(
      "brms",
      "ggstatsplot",
      "rstanarm"
    )
  )
)

#' Install Missing Packages
#' @param pkgs A character vector of package names to check and install if missing.
#' @param ... Additional arguments passed to the `install.packages` function.
install_if_missing <- function(pkgs, ...) {
  require_silent <- function(pkg) {
    suppressPackageStartupMessages(
      require(pkg, character.only = TRUE, quietly = TRUE)
    )
  }

  is_installed <- vapply(pkgs, require_silent, logical(1))
  remotes::install_cran(pkgs[!is_installed], ...)
}

#' Resolve Dependencies for an Environment
#' @param env The environment for which dependencies need to be resolved.
#' @return A character vector of environment names.
resolve_dependencies <- function(env) {
  deps <- c(environments[[env]]$depends, env)
  for (dep in environments[[env]]$depends) {
    deps <- c(resolve_dependencies(dep), deps)
  }
  return(unique(deps))
}

#' Install the specified environment
#' @param env A character string specifying the name of the environment to install.
install_env <- function(env) {
  cat("Installing packages for", env, "environment...\n")
  remotes::install_cran(environments[[env]]$force_cran)
  install_if_missing(environments[[env]]$cran)
  remotes::install_github(environments[[env]]$github)
}

# Define command-line options
option_list <- list(
  optparse::make_option(c("-e", "--environment"),
    type = "character", default = "base-r",
    help = "Environment name [default: %default]", metavar = "character"
  )
)

# Parse command-line options
opt_parser <- optparse::OptionParser(option_list = option_list)
opt <- optparse::parse_args(opt_parser)

# Validate environment
if (opt$environment %in% names(environments)) {
  cat("Selected environment:", opt$environment, "\n")
} else {
  rlang::abort(c(
    paste("Invalid environment:", opt$environment),
    "*" = paste("Accepted environments are: ", paste(accepted_environments, collapse = ", "))
  ))
}

# Install the required packages
deps <- resolve_dependencies(opt$environment)
cat(paste("Environment dependencies:", paste(deps, collapse = ", ")), "\n")
for (dep in deps) install_env(dep)

# Extra packages that need a different repository
# Don't want to just add the repository, because we only want this specific package from it
if (opt$environment == "datascience-notebook") {
  install_if_missing(repos = "https://mc-stan.org/r-packages/", "cmdstanr")
  remotes::install_github("rmcelreath/rethinking")
}

options(warn = 2)

# Parse command-line options
opt_parser <- optparse::OptionParser(
  usage = "Usage: %prog [options]",
  option_list = list(
    optparse::make_option(c("-e", "--environment"),
      type = "character", default = "base-r",
      help = "Environment name [default: %default]", metavar = "character"
    )
  )
)
opt <- optparse::parse_args(opt_parser)


#' Define an Environment
#' @param name The name of the environment.
#' @param aliases A character vector of aliases for the environment.
#' @param depends A character vector of environment names on which this environment depends.
#' @param cran A character vector of R packages to install from CRAN.
#' @param force_cran A character vector of packages to install from CRAN, even if already installed.
#' @param github A character vector of R packages hosted on GitHub to install.
#' @param pre_install A function to run before installing packages.
#' @param post_install A function to run after installing packages.
#' @param hidden A logical value indicating whether the environment is hidden in CLI outputs.
#' @return A list representing the environment.
make_env <- function(
    name, aliases = character(0), depends = character(0),
    force_cran = character(0), github = character(0), cran = character(0),
    pre_install = NULL, post_install = NULL,
    hidden = FALSE) {
  list(
    name = name,
    aliases = aliases,
    depends = depends,
    force_cran = force_cran,
    github = github,
    cran = cran,
    pre_install = pre_install,
    post_install = post_install,
    hidden = hidden
  )
}

#' Validate Environment
#' @param env A character string representing the environment to validate.
#' @param envs A character vector containing the list of valid environments.
validate_env <- function(env, envs) {
  all_aliases <- unlist(lapply(envs, function(env) c(env$name, env$aliases)))
  available_envs <- paste(
    Filter(Negate(is.null), lapply(envs, function(env) {
      if (!env$hidden) {
        aliases <- c(env$name, env$aliases)
        aliases <- aliases[aliases != ""]
        aliases <- paste(aliases, collapse = ", ")
        sprintf("  - %s (aliases: %s)", env$name, aliases)
      }
    })),
    collapse = "\n"
  )

  if (!(env %in% all_aliases)) {
    rlang::abort(c(
      paste("Invalid environment:", env),
      "*" = paste("Accepted environments are:\n", substring(available_envs, 2))
    ))
  }
}

#' Check GitHub Personal Access Token (PAT)
#'
#' If there are environments that need to install GitHub packages, this function checks the
#' availability a GitHub Personal Access Token (PAT) for performing authenticated API requests.
#'
#' @param deps A character vector of dependencies that may require GitHub access.
#' @param envs A list of environments containing the GitHub repositories to install.
check_github_pat <- function(deps, envs) {
  for (dep in deps) {
    if (length(envs[[dep]]$github) > 0 && is.null(Sys.getenv("GITHUB_PAT"))) {
      rlang::abort("The GITHUB_PAT environment variable is required to install GitHub packages.")
    }
  }
}

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
  cat("Skipping installed packages:", paste(pkgs[is_installed], collapse = ", "), "\n")
  remotes::install_cran(pkgs[!is_installed], ...)
}

#' Resolve Dependencies for an Environment
#' @param env_name The name of the environment for which dependencies need to be resolved.
#' @param envs A list of environments containing the dependencies.
#' @return A character vector of environment names.
resolve_dependencies <- function(env_name, envs) {
  deps <- c(envs[[env_name]]$depends, env_name)
  for (dep in envs[[env_name]]$depends) {
    validate_env(dep, envs)
    deps <- c(resolve_dependencies(dep, envs), deps)
  }
  return(unique(deps))
}

#' Install the specified environment
#' @param env A list representing the environment to install.
install_env <- function(env) {
  if (rlang::is_function(env$pre_install)) {
    cat("Running pre-installation hook for", env$name, "environment...\n")
    env$pre_install()
  }

  cat("Installing packages for", env$name, "environment...\n")
  remotes::install_cran(env$force_cran)
  install_if_missing(env$cran)
  remotes::install_github(env$github)

  if (rlang::is_function(env$post_install)) {
    cat("Running post-installation hook for", env$name, "environment...\n")
    env$post_install()
  }
}

# Define the list of environments
environments <- list(
  "base-r" = make_env(
    name = "base-r"
  ),
  "essentials" = make_env(
    name = "essentials",
    aliases = c("deepnote-essentials", "ckcode"),
    depends = c("base-r"),
    force_cran = c(
      "coursekata"
    ),
    github = c(
      "coursekata/fivethirtyeightdata",
      "coursekata/Lock5withR",
      "coursekata/testwhat"
    ),
    cran = c(
      "fivethirtyeight",
      "ggpubr",
      "gridExtra",
      "lme4",
      "plotly",
      "statmod"
    )
  ),
  "r" = make_env(
    name = "r",
    aliases = c("deepnote-r"),
    depends = c("essentials"),
    force_cran = c(
      "V8"
    ),
    github = c(
      "mobilizingcs/mobilizr"
    ),
    cran = c(
      "av",
      "bayesplot",
      "broom.mixed",
      "car",
      "dagitty",
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
  "datascience-base" = make_env(
    name = "datascience-base",
    hidden = TRUE,
    depends = c("r"),
    github = c(
      "dustinfife/flexplot",
      "flxzimmer/mlpwr"
    ),
    cran = c(
      "brms",
      "dlookr",
      "extraDistr",
      "ggstatsplot",
      "modelsummary",
      "pwr",
      "pwrss",
      "rstanarm",
      "skimr",
      "tidyplots"
    ),
    post_install = function() {
      remotes::install_cran("cmdstanr", repos = "https://stan-dev.r-universe.dev")
      cmdstanr::install_cmdstan()
    }
  ),
  "datascience" = make_env(
    name = "datascience",
    aliases = c("deepnote-datascience", "ckhub"),
    depends = c("datascience-base"),
    github = c(
      "rmcelreath/rethinking"
    )
  )
)

# Install the specified environment
validate_env(opt$environment, environments)
cat("Selected environment:", opt$environment, "\n")

deps <- resolve_dependencies(opt$environment, environments)
cat(paste("Environment dependencies:", paste(deps, collapse = ", ")), "\n")

check_github_pat(deps, environments)
for (dep in deps) install_env(environments[[dep]])

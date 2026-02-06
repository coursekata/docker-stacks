#!/usr/bin/env Rscript

#' rpixi - Install R packages from rpixi.toml
#'
#' A CLI tool for installing R packages based on environment specifications
#' in a rpixi.toml file, emulating the pixi interface.
#'
#' @section File Structure:
#' This monofile script is organized from high-level to low-level:
#' 1. Constants & Configuration
#' 2. Bootstrap & Dependency Management
#' 3. Main Entry Point & Dispatch
#' 4. Commands (parser + handler grouped for each command)
#' 5. Environment Operations
#' 6. Configuration Management
#' 7. Package Management
#' 8. Utility Functions
#' 9. Script Execution

# =============================================================================
# Constants & Configuration
# =============================================================================

# nolint start: object_name_linter
VERSION <- "1.0.0"

# Exit codes
EXIT_SUCCESS <- 0
EXIT_ERROR <- 1
EXIT_VALIDATION_ERROR <- 2
EXIT_ENVIRONMENT_ERROR <- 3
EXIT_DEPENDENCY_ERROR <- 4
EXIT_INSTALLATION_ERROR <- 5
EXIT_AUTH_ERROR <- 6
EXIT_NETWORK_ERROR <- 7
# nolint end

# =============================================================================
# Bootstrap & Dependency Management
# =============================================================================

#' Get list of missing required packages
#'
#' @return Character vector of missing package names
get_missing_packages <- function() {
  required_packages <- c("optparse", "RcppTOML", "remotes", "rlang")
  Filter(function(pkg) !requireNamespace(pkg, quietly = TRUE), required_packages)
}

#' Bootstrap script dependencies
#'
#' Installs required packages that rpixi needs to function. Can be run
#' interactively or automatically.
#'
#' @param auto_accept Logical. If TRUE, install without prompting user
#' @return Invisible TRUE on success
bootstrap_dependencies <- function(auto_accept = FALSE) {
  missing_packages <- get_missing_packages()

  if (length(missing_packages) == 0) {
    return(invisible(TRUE))
  }

  cat("Missing required packages:", paste(missing_packages, collapse = ", "), "\n")

  if (!auto_accept) {
    response <- readline(prompt = "Install missing packages? [Y/n]: ")
    if (!(tolower(response) %in% c("", "y", "yes"))) {
      stop("Cannot proceed without required packages", call. = FALSE)
    }
  } else {
    cat("Auto-installing missing packages...\n")
  }

  # Install missing packages
  for (pkg in missing_packages) {
    cat("Installing", pkg, "...\n")
    tryCatch(
      {
        install.packages(pkg, repos = "https://cloud.r-project.org/", quiet = TRUE)
      },
      error = function(e) {
        stop(paste0("Failed to install ", pkg, ": ", e$message), call. = FALSE)
      }
    )
  }

  cat("All required packages installed successfully\n")
  invisible(TRUE)
}

# Check for bootstrap subcommand before loading dependencies
args_raw <- commandArgs(trailingOnly = TRUE)
if (length(args_raw) > 0 && args_raw[1] == "bootstrap") {
  # Bootstrap has --auto flag instead of separate command
  auto_accept <- "--auto" %in% args_raw
  bootstrap_dependencies(auto_accept = auto_accept)
  quit(status = 0, save = "no")
}

# Ensure required packages are available
missing_packages <- get_missing_packages()

if (length(missing_packages) > 0) {
  cat(
    "Error: Missing required packages:",
    paste(missing_packages, collapse = ", "), "\n",
    file = stderr()
  )
  cat("Run 'rpixi bootstrap' to install dependencies interactively\n", file = stderr())
  cat("Run 'rpixi bootstrap --auto' to install dependencies automatically\n", file = stderr())
  quit(status = 1, save = "no")
}

suppressPackageStartupMessages({
  library(optparse)
  library(rlang)
})

# =============================================================================
# Main Entry Point & Dispatch
# =============================================================================

#' Dispatch to subcommand handler
#'
#' Routes the command to the appropriate handler function.
#'
#' @param cmd Character. Subcommand name (install, list, tree, info, validate)
#' @param args Character vector. Arguments to pass to subcommand handler
dispatch_command <- function(cmd, args) {
  switch(cmd,
    "install" = cmd_install(args),
    "list" = cmd_list(args),
    "tree" = cmd_tree(args),
    "info" = cmd_info(args),
    "validate" = cmd_validate(args),
    "pakgen" = cmd_pakgen(args),
    abort(c(
      "Unknown command",
      "x" = paste("Unknown command:", cmd),
      "i" = "Valid commands: install, list, tree, info, validate, pakgen, bootstrap"
    ))
  )
}

#' Main entry point with subcommand dispatch
#'
#' Parses command-line arguments to determine which subcommand to run,
#' then dispatches to the appropriate handler. Shows help if no command given.
main <- function() {
  args_raw <- commandArgs(trailingOnly = TRUE)

  # Determine subcommand
  valid_commands <- c("install", "list", "tree", "info", "validate", "pakgen")

  if (length(args_raw) == 0) {
    # No args: show help
    cat("Usage: rpixi <COMMAND> [OPTIONS]\n\n")
    cat("Commands:\n")
    cat("  install    Install R packages for an environment\n")
    cat("  list       List R packages for an environment\n")
    cat("  tree       Show dependency tree for an environment\n")
    cat("  info       Show available environments\n")
    cat("  validate   Validate rpixi.toml syntax\n")
    cat("  pakgen     Generate standalone pak installer scripts\n")
    cat("  bootstrap  Install rpixi dependencies\n")
    cat("\nRun 'rpixi <COMMAND> --help' for more information on a command.\n")
    quit(status = EXIT_SUCCESS, save = "no")
  }

  if (args_raw[1] %in% valid_commands) {
    cmd <- args_raw[1]
    cmd_args <- if (length(args_raw) > 1) args_raw[-1] else character()
  } else if (startsWith(args_raw[1], "-")) {
    # Starts with flag: default to install command
    cmd <- "install"
    cmd_args <- args_raw
  } else {
    abort(c(
      "Unknown command",
      "x" = paste("Unknown command:", args_raw[1]),
      "i" = "Valid commands: install, list, tree, info, validate, pakgen, bootstrap",
      "i" = "Run 'rpixi' without arguments to see usage"
    ))
  }

  dispatch_command(cmd, cmd_args)
}

# =============================================================================
# Commands
# =============================================================================

#' Parse install command arguments
#'
#' @param cmd_args Character vector. Command-line arguments to parse
#' @return List of parsed arguments
parse_install_args <- function(cmd_args = character()) {
  option_list <- list(
    make_option(c("-e", "--environment"),
      type = "character", default = "default",
      help = "Install packages for the specified environment [default: %default]",
      metavar = "NAME"
    ),
    make_option(c("-a", "--all"),
      action = "store_true", default = FALSE,
      help = "Install packages for all environments"
    ),
    make_option("--manifest-path",
      type = "character", default = "./rpixi.toml",
      help = "Path to rpixi.toml file [default: %default]",
      metavar = "PATH", dest = "manifest_path"
    ),
    make_option("--force",
      action = "store_true", default = FALSE,
      help = "Force reinstallation of all packages"
    ),
    make_option("--skip-installed",
      action = "store_true", default = TRUE,
      help = "Skip packages that are already installed [default: %default]",
      dest = "skip_installed"
    ),
    make_option("--no-skip-installed",
      action = "store_false", dest = "skip_installed",
      help = "Do not skip installed packages"
    ),
    make_option(c("-v", "--verbose"),
      action = "store_true", default = FALSE,
      help = "Increase verbosity", dest = "verbose"
    ),
    make_option(c("-q", "--quiet"),
      action = "store_true", default = FALSE,
      help = "Suppress all non-error output"
    ),
    make_option(c("-n", "--dry-run"),
      action = "store_true", default = FALSE,
      help = "Show what would be installed without installing",
      dest = "dry_run"
    ),
    make_option("--github-token",
      type = "character", default = Sys.getenv("GITHUB_PAT", ""),
      help = "GitHub Personal Access Token [default: $GITHUB_PAT]",
      metavar = "TOKEN", dest = "github_token"
    ),
    make_option("--version",
      action = "store_true", default = FALSE,
      help = "Show version and exit"
    )
  )

  parser <- OptionParser(
    usage = "usage: %prog [OPTIONS]",
    option_list = option_list,
    description = paste(
      "\nInstall R packages from rpixi.toml with environment-based dependency management.",
      "\nEmulates pixi patterns for consistency."
    )
  )

  args <- optparse::parse_args(parser, args = cmd_args, positional_arguments = FALSE)

  # Handle NULL values and set defaults
  if (is_null(args$environment)) args$environment <- "default"
  if (is_null(args$verbose)) args$verbose <- FALSE
  if (is_null(args$quiet)) args$quiet <- FALSE
  if (is_null(args$all)) args$all <- FALSE
  if (is_null(args$force)) args$force <- FALSE
  if (is_null(args$skip_installed)) args$skip_installed <- TRUE
  if (is_null(args$dry_run)) args$dry_run <- FALSE
  if (is_null(args$github_token)) args$github_token <- ""
  if (is_null(args$manifest_path)) args$manifest_path <- "./rpixi.toml"

  # Validate argument combinations
  if (args$all && args$environment != "default") {
    abort(c(
      "Cannot specify both --all and --environment",
      "i" = "Use --all to install all environments, or -e to select one"
    ))
  }

  if (args$quiet && args$verbose) {
    abort(c(
      "Cannot specify both --quiet and --verbose",
      "i" = "Choose one output mode"
    ))
  }

  args
}

#' Install command handler
#'
#' Handles the 'rpixi install' subcommand. Parses arguments, reads configuration,
#' and installs R packages for the specified environment(s).
#'
#' @param cmd_args Character vector. Command-line arguments for install command
cmd_install <- function(cmd_args) {
  # Parse install-specific arguments
  args <- tryCatch(
    parse_install_args(cmd_args),
    error = function(e) {
      abort(c(
        "Failed to parse arguments",
        "x" = e$message
      ), call = NULL)
    }
  )

  # Print header
  header_msg <- paste0("rpixi v", VERSION, if (args$dry_run) " (dry-run)" else "")
  log_info(header_msg, args$quiet)

  # Read and parse rpixi.toml
  log_verbose("Reading rpixi.toml...", args$verbose, args$quiet)
  config <- tryCatch(
    read_requirements(args$manifest_path, args),
    error = function(e) {
      abort(c(
        "Failed to read rpixi.toml",
        "x" = e$message,
        "i" = paste("Path:", args$manifest_path)
      ), call = NULL)
    }
  )

  # Determine environments to install
  if (args$all) {
    envs_to_install <- names(config$environments)
    log_info(
      paste("Installing all environments:", paste(envs_to_install, collapse = ", ")),
      args$quiet
    )
  } else {
    envs_to_install <- args$environment
    log_info(paste("Selected environment:", envs_to_install), args$quiet)
  }

  # Validate environments exist
  valid_envs <- get_valid_environments(config)
  for (env in envs_to_install) {
    if (!env %in% valid_envs) {
      abort(c(
        "Environment not found",
        "x" = paste("Invalid environment:", env),
        "i" = "Available environments:",
        set_names(paste("", valid_envs), rep("*", length(valid_envs)))
      ), call = NULL)
    }
  }

  # Set up GitHub authentication
  if (nzchar(args$github_token)) {
    Sys.setenv(GITHUB_PAT = args$github_token)
    log_verbose("GitHub token configured", args$verbose, args$quiet)
  }

  # Install packages for each environment
  total_installed <- 0
  total_skipped <- 0
  start_time <- Sys.time()

  for (env in envs_to_install) {
    result <- tryCatch(
      install_environment(env, config, args),
      error = function(e) {
        abort(c(
          "Installation failed",
          "x" = paste("Failed to install environment:", env),
          "i" = e$message
        ), call = NULL)
      }
    )

    total_installed <- total_installed + result$installed
    total_skipped <- total_skipped + result$skipped
  }

  # Print summary
  elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))
  elapsed_str <- if (elapsed < 60) {
    sprintf("%.0fs", elapsed)
  } else if (elapsed < 3600) {
    sprintf("%dm %ds", floor(elapsed / 60), round(elapsed %% 60))
  } else {
    sprintf("%dh %dm", floor(elapsed / 3600), round((elapsed %% 3600) / 60))
  }

  if (!args$dry_run) {
    log_info(paste0(
      "\nInstallation complete: ", total_installed, " packages installed, ",
      total_skipped, " skipped"
    ), args$quiet)
    log_info(paste("Time elapsed:", elapsed_str), args$quiet)
  } else {
    log_info(paste0("\nTotal: ", total_installed, " packages"), args$quiet)
  }

  quit(status = EXIT_SUCCESS, save = "no")
}


#' Parse list command arguments
#'
#' @param cmd_args Character vector. Command-line arguments to parse
#' @return List of parsed arguments
parse_list_args <- function(cmd_args = character()) {
  parser <- optparse::OptionParser(
    usage = "rpixi list [options]",
    description = "List R packages for an environment"
  )

  parser <- optparse::add_option(parser,
    c("-e", "--environment"),
    type = "character",
    default = "default",
    help = "Environment to list packages for [default: %default]",
    metavar = "ENV",
    dest = "environment"
  )

  parser <- optparse::add_option(parser,
    c("-m", "--manifest-path"),
    type = "character",
    default = "./rpixi.toml",
    help = "Path to rpixi.toml [default: %default]",
    metavar = "PATH",
    dest = "manifest_path"
  )

  parser <- optparse::add_option(parser,
    c("-v", "--verbose"),
    action = "store_true", default = FALSE,
    help = "Enable verbose output",
    dest = "verbose"
  )

  parser <- optparse::add_option(parser,
    c("-q", "--quiet"),
    action = "store_true", default = FALSE,
    help = "Suppress non-essential output",
    dest = "quiet"
  )

  args <- optparse::parse_args(parser, args = cmd_args, positional_arguments = FALSE)

  # Handle NULL values
  if (is_null(args$environment)) args$environment <- "default"
  if (is_null(args$verbose)) args$verbose <- FALSE
  if (is_null(args$quiet)) args$quiet <- FALSE
  if (is_null(args$manifest_path)) args$manifest_path <- "./rpixi.toml"

  args
}

#' List command handler
#'
#' Handles the 'rpixi list' subcommand. Lists all R packages for an environment.
#'
#' @param cmd_args Character vector. Command-line arguments for list command
cmd_list <- function(cmd_args) {
  args <- tryCatch(
    parse_list_args(cmd_args),
    error = function(e) {
      abort(c(
        "Failed to parse arguments",
        "x" = e$message
      ), call = NULL)
    }
  )

  # Read config
  config <- tryCatch(
    read_requirements(args$manifest_path, args),
    error = function(e) {
      abort(c(
        "Failed to read rpixi.toml",
        "x" = e$message,
        "i" = paste("Path:", args$manifest_path)
      ), call = NULL)
    }
  )

  # Call existing list_packages function
  list_packages(args$environment, config, args)
  quit(status = EXIT_SUCCESS, save = "no")
}

#' Parse tree command arguments
#'
#' @param cmd_args Character vector. Command-line arguments to parse
#' @return List of parsed arguments
parse_tree_args <- function(cmd_args = character()) {
  parser <- optparse::OptionParser(
    usage = "rpixi tree [options]",
    description = "Show dependency tree for an environment"
  )

  parser <- optparse::add_option(parser,
    c("-e", "--environment"),
    type = "character",
    default = "default",
    help = "Environment to show dependencies for [default: %default]",
    metavar = "ENV",
    dest = "environment"
  )

  parser <- optparse::add_option(parser,
    c("-m", "--manifest-path"),
    type = "character",
    default = "./rpixi.toml",
    help = "Path to rpixi.toml [default: %default]",
    metavar = "PATH",
    dest = "manifest_path"
  )

  parser <- optparse::add_option(parser,
    c("-v", "--verbose"),
    action = "store_true", default = FALSE,
    help = "Enable verbose output",
    dest = "verbose"
  )

  parser <- optparse::add_option(parser,
    c("-q", "--quiet"),
    action = "store_true", default = FALSE,
    help = "Suppress non-essential output",
    dest = "quiet"
  )

  args <- optparse::parse_args(parser, args = cmd_args, positional_arguments = FALSE)

  # Handle NULL values
  if (is_null(args$environment)) args$environment <- "default"
  if (is_null(args$verbose)) args$verbose <- FALSE
  if (is_null(args$quiet)) args$quiet <- FALSE
  if (is_null(args$manifest_path)) args$manifest_path <- "./rpixi.toml"

  args
}

#' Tree command handler
#'
#' Handles the 'rpixi tree' subcommand. Shows dependency tree for an environment.
#'
#' @param cmd_args Character vector. Command-line arguments for tree command
cmd_tree <- function(cmd_args) {
  args <- tryCatch(
    parse_tree_args(cmd_args),
    error = function(e) {
      abort(c(
        "Failed to parse arguments",
        "x" = e$message
      ), call = NULL)
    }
  )

  # Read config
  config <- tryCatch(
    read_requirements(args$manifest_path, args),
    error = function(e) {
      abort(c(
        "Failed to read rpixi.toml",
        "x" = e$message,
        "i" = paste("Path:", args$manifest_path)
      ), call = NULL)
    }
  )

  # Call existing show_dependencies function
  show_dependencies(args$environment, config, args)
  quit(status = EXIT_SUCCESS, save = "no")
}

#' Parse info command arguments
#'
#' @param cmd_args Character vector. Command-line arguments to parse
#' @return List of parsed arguments
parse_info_args <- function(cmd_args = character()) {
  parser <- optparse::OptionParser(
    usage = "rpixi info [options]",
    description = "Show available environments"
  )

  parser <- optparse::add_option(parser,
    c("-m", "--manifest-path"),
    type = "character",
    default = "./rpixi.toml",
    help = "Path to rpixi.toml [default: %default]",
    metavar = "PATH",
    dest = "manifest_path"
  )

  parser <- optparse::add_option(parser,
    c("-v", "--verbose"),
    action = "store_true", default = FALSE,
    help = "Enable verbose output",
    dest = "verbose"
  )

  parser <- optparse::add_option(parser,
    c("-q", "--quiet"),
    action = "store_true", default = FALSE,
    help = "Suppress non-essential output",
    dest = "quiet"
  )

  args <- optparse::parse_args(parser, args = cmd_args, positional_arguments = FALSE)

  # Handle NULL values
  if (is_null(args$verbose)) args$verbose <- FALSE
  if (is_null(args$quiet)) args$quiet <- FALSE
  if (is_null(args$manifest_path)) args$manifest_path <- "./rpixi.toml"

  args
}

#' Info command handler
#'
#' Handles the 'rpixi info' subcommand. Shows all available environments and
#' their package counts.
#'
#' @param cmd_args Character vector. Command-line arguments for info command
cmd_info <- function(cmd_args) {
  args <- tryCatch(
    parse_info_args(cmd_args),
    error = function(e) {
      abort(c(
        "Failed to parse arguments",
        "x" = e$message
      ), call = NULL)
    }
  )

  # Read config
  config <- tryCatch(
    read_requirements(args$manifest_path, args),
    error = function(e) {
      abort(c(
        "Failed to read rpixi.toml",
        "x" = e$message,
        "i" = paste("Path:", args$manifest_path)
      ), call = NULL)
    }
  )

  # Call existing list_environments function
  list_environments(config, args)
  quit(status = EXIT_SUCCESS, save = "no")
}

#' Parse validate command arguments
#'
#' @param cmd_args Character vector. Command-line arguments to parse
#' @return List of parsed arguments
parse_validate_args <- function(cmd_args = character()) {
  parser <- optparse::OptionParser(
    usage = "rpixi validate [options]",
    description = "Validate rpixi.toml syntax"
  )

  parser <- optparse::add_option(parser,
    c("-m", "--manifest-path"),
    type = "character",
    default = "./rpixi.toml",
    help = "Path to rpixi.toml [default: %default]",
    metavar = "PATH",
    dest = "manifest_path"
  )

  parser <- optparse::add_option(parser,
    c("-v", "--verbose"),
    action = "store_true", default = FALSE,
    help = "Enable verbose output",
    dest = "verbose"
  )

  parser <- optparse::add_option(parser,
    c("-q", "--quiet"),
    action = "store_true", default = FALSE,
    help = "Suppress non-essential output",
    dest = "quiet"
  )

  args <- optparse::parse_args(parser, args = cmd_args, positional_arguments = FALSE)

  # Handle NULL values
  if (is_null(args$verbose)) args$verbose <- FALSE
  if (is_null(args$quiet)) args$quiet <- FALSE
  if (is_null(args$manifest_path)) args$manifest_path <- "./rpixi.toml"

  args
}

#' Validate command handler
#'
#' Handles the 'rpixi validate' subcommand. Validates rpixi.toml syntax and
#' structure without installing anything.
#'
#' @param cmd_args Character vector. Command-line arguments for validate command
cmd_validate <- function(cmd_args) {
  args <- tryCatch(
    parse_validate_args(cmd_args),
    error = function(e) {
      abort(c(
        "Failed to parse arguments",
        "x" = e$message
      ), call = NULL)
    }
  )

  # Read config (this validates structure)
  # nolint start: object_usage_linter
  config <- tryCatch(
    read_requirements(args$manifest_path, args),
    error = function(e) {
      abort(c(
        "Validation failed",
        "x" = e$message,
        "i" = paste("Path:", args$manifest_path)
      ), call = NULL)
    }
  )
  # nolint end

  # If we got here, validation succeeded
  log_info("rpixi.toml is valid", args$quiet)
  quit(status = EXIT_SUCCESS, save = "no")
}

#' Parse pakgen command arguments
#'
#' @param cmd_args Character vector. Command-line arguments to parse
#' @return List of parsed arguments
parse_pakgen_args <- function(cmd_args = character()) {
  parser <- optparse::OptionParser(
    usage = "rpixi pakgen [options]",
    description = paste(
      "\nGenerate standalone R scripts that install packages using pak.",
      "\nGenerated scripts are self-contained and can be run with Rscript."
    )
  )

  parser <- optparse::add_option(parser,
    c("-e", "--environment"),
    type = "character",
    default = NULL,
    help = "Environment to generate script for",
    metavar = "ENV",
    dest = "environment"
  )

  parser <- optparse::add_option(parser,
    c("-a", "--all"),
    action = "store_true", default = FALSE,
    help = "Generate scripts for all environments"
  )

  parser <- optparse::add_option(parser,
    c("-o", "--output-dir"),
    type = "character",
    default = "./pak-scripts",
    help = "Output directory for generated scripts [default: %default]",
    metavar = "PATH",
    dest = "output_dir"
  )

  parser <- optparse::add_option(parser,
    c("-m", "--manifest-path"),
    type = "character",
    default = "./rpixi.toml",
    help = "Path to rpixi.toml [default: %default]",
    metavar = "PATH",
    dest = "manifest_path"
  )

  parser <- optparse::add_option(parser,
    c("-v", "--verbose"),
    action = "store_true", default = FALSE,
    help = "Enable verbose output",
    dest = "verbose"
  )

  parser <- optparse::add_option(parser,
    c("-q", "--quiet"),
    action = "store_true", default = FALSE,
    help = "Suppress non-essential output",
    dest = "quiet"
  )

  args <- optparse::parse_args(parser, args = cmd_args, positional_arguments = FALSE)

  # Handle NULL values
  if (is_null(args$verbose)) args$verbose <- FALSE
  if (is_null(args$quiet)) args$quiet <- FALSE
  if (is_null(args$all)) args$all <- FALSE
  if (is_null(args$output_dir)) args$output_dir <- "./pak-scripts"
  if (is_null(args$manifest_path)) args$manifest_path <- "./rpixi.toml"

  # Validate: must specify either --all or --environment
  if (!args$all && is_null(args$environment)) {
    abort(c(
      "No environment specified",
      "x" = "Must specify either --environment or --all",
      "i" = "Use -e ENV to generate for a specific environment",
      "i" = "Use -a to generate for all environments"
    ))
  }

  # Validate: cannot specify both --all and --environment
  if (args$all && !is_null(args$environment)) {
    abort(c(
      "Cannot specify both --all and --environment",
      "i" = "Use --all to generate all environments, or -e to select one"
    ))
  }

  args
}

#' Pakgen command handler
#'
#' Handles the 'rpixi pakgen' subcommand. Generates standalone pak installer
#' scripts for one or all environments.
#'
#' @param cmd_args Character vector. Command-line arguments for pakgen command
cmd_pakgen <- function(cmd_args) {
  args <- tryCatch(
    parse_pakgen_args(cmd_args),
    error = function(e) {
      abort(c(
        "Failed to parse arguments",
        "x" = e$message
      ), call = NULL)
    }
  )

  # Print header
  log_info(paste0("rpixi pakgen v", VERSION), args$quiet)

  # Read config
  config <- tryCatch(
    read_requirements(args$manifest_path, args),
    error = function(e) {
      abort(c(
        "Failed to read rpixi.toml",
        "x" = e$message,
        "i" = paste("Path:", args$manifest_path)
      ), call = NULL)
    }
  )

  # Determine environments to generate
  valid_envs <- get_valid_environments(config)
  if (args$all) {
    envs_to_generate <- valid_envs
  } else {
    if (!args$environment %in% valid_envs) {
      abort(c(
        "Environment not found",
        "x" = paste("Invalid environment:", args$environment),
        "i" = "Available environments:",
        set_names(paste("", valid_envs), rep("*", length(valid_envs)))
      ), call = NULL)
    }
    envs_to_generate <- args$environment
  }

  # Create output directory
  if (!dir.exists(args$output_dir)) {
    log_verbose(paste("Creating output directory:", args$output_dir), args$verbose, args$quiet)
    tryCatch(
      dir.create(args$output_dir, recursive = TRUE),
      error = function(e) {
        abort(c(
          "Failed to create output directory",
          "x" = paste("Path:", args$output_dir),
          "i" = e$message
        ), call = NULL)
      }
    )
  }

  # Generate scripts
  generated_files <- character()
  for (env in envs_to_generate) {
    log_info(paste("Generating script for:", env), args$quiet)
    output_path <- file.path(args$output_dir, paste0(env, ".R"))

    tryCatch(
      {
        script_content <- generate_pak_script(env, config, args)
        writeLines(script_content, output_path)
        Sys.chmod(output_path, "755")
        generated_files <- c(generated_files, output_path)
        log_verbose(paste("  Written:", output_path), args$verbose, args$quiet)
      },
      error = function(e) {
        abort(c(
          "Failed to generate script",
          "x" = paste("Environment:", env),
          "i" = e$message
        ), call = NULL)
      }
    )
  }

  # Print summary
  log_info(paste0(
    "\nGenerated ", length(generated_files), " script(s) in ", args$output_dir
  ), args$quiet)

  quit(status = EXIT_SUCCESS, save = "no")
}

# =============================================================================
# Environment Operations
# =============================================================================

#' List all available environments
#'
#' Displays all available environments with their features and package counts
#' in a format similar to pixi's info output.
#'
#' @param config List. Parsed rpixi.toml configuration
#' @param args List. Parsed arguments (for quiet mode)
list_environments <- function(config, args) {
  if (!args$quiet) {
    cat("Available environments:\n\n")
  }

  # Show default environment first (implicit from [dependencies])
  cat("        Environment: default\n")
  cat("           Features: default\n")

  # Count base dependencies
  base_deps <- if (!is_null(config$dependencies)) names(config$dependencies) else character()
  cat(sprintf("   Dependency count: %d\n", length(base_deps)))
  if (length(base_deps) > 0) {
    cat(sprintf("       Dependencies: %s\n", paste(base_deps, collapse = ", ")))
  }
  cat("\n")

  # Show explicit environments
  for (env_name in names(config$environments)) {
    env <- config$environments[[env_name]]

    # All environments implicitly include "default" feature (listed last like pixi)
    features <- c(env$features, "default")
    features_str <- paste(features, collapse = ", ")

    cat(sprintf("        Environment: %s\n", env_name))
    cat(sprintf("           Features: %s\n", features_str))

    # Get all packages for this environment
    deps <- resolve_dependencies(env_name, config, args = args)
    all_packages <- character()
    for (dep in deps) {
      pkgs <- get_feature_packages(dep, config)
      if (length(pkgs) > 0) {
        all_packages <- c(all_packages, names(pkgs))
      }
    }
    all_packages <- unique(all_packages)

    cat(sprintf("   Dependency count: %d\n", length(all_packages)))
    if (length(all_packages) > 0) {
      cat(sprintf("       Dependencies: %s\n", paste(all_packages, collapse = ", ")))
    }
    cat("\n")
  }
}

#' Resolve environment dependencies recursively
#'
#' Resolves an environment's dependencies by following its feature chain.
#' Returns a vector of feature names to process in order.
#'
#' @param env_name Character. Name of environment to resolve
#' @param config List. Parsed rpixi.toml configuration
#' @param resolved Character vector. Already-resolved environments (for cycle detection)
#' @param args List. Parsed arguments (for logging verbosity)
#' @return Character vector of feature names in dependency order
resolve_dependencies <- function(env_name, config, resolved = character(), args) {
  log_verbose(paste("Resolving dependencies for:", env_name), args$verbose, args$quiet)

  # Handle special "default" environment (implicit from [dependencies])
  if (env_name == "default") {
    return("base")
  }

  # Check if environment exists
  valid_envs <- get_valid_environments(config)
  if (!env_name %in% valid_envs) {
    abort(c(
      "Environment not found",
      "x" = paste("Invalid environment:", env_name),
      "i" = "Available environments:",
      set_names(paste("", valid_envs), rep("*", length(valid_envs)))
    ), call = caller_env())
  }

  env <- config$environments[[env_name]]

  # Get features for this environment
  features <- if (is_null(env$features)) character() else env$features

  # Check for circular dependencies
  if (env_name %in% resolved) {
    abort(c(
      "Circular dependency detected",
      "x" = paste("Environment", env_name, "depends on itself"),
      "i" = "Check environment feature definitions"
    ), .internal = TRUE, call = caller_env())
  }

  # Add this environment to resolved list
  resolved <- c(resolved, env_name)

  # Return unique list of environments (base dependencies first)
  unique(c("base", features, env_name))
}

#' Show dependency tree for an environment
#'
#' Displays the dependency tree showing how an environment's dependencies
#' are resolved.
#'
#' @param env_name Character. Name of environment
#' @param config List. Parsed rpixi.toml configuration
#' @param args List. Parsed arguments (for quiet mode)
show_dependencies <- function(env_name, config, args) {
  valid_envs <- get_valid_environments(config)
  if (!env_name %in% valid_envs) {
    abort(c(
      "Environment not found",
      "x" = paste("Invalid environment:", env_name),
      "i" = "Available environments:",
      set_names(paste("", valid_envs), rep("*", length(valid_envs)))
    ), call = NULL)
  }

  deps <- resolve_dependencies(env_name, config, args = args)
  log_info(paste("Dependency tree for", env_name, ":"), args$quiet)
  for (i in seq_along(deps)) {
    log_info(paste0("  ", i, ". ", deps[i]), args$quiet)
  }
}

#' List all R packages for an environment
#'
#' Lists all R packages that belong to an environment, one per line.
#' Output format is designed for easy consumption by bash scripts.
#'
#' @param env_name Character. Name of environment
#' @param config List. Parsed rpixi.toml configuration
#' @param args List. Parsed arguments (for logging verbosity)
list_packages <- function(env_name, config, args) {
  valid_envs <- get_valid_environments(config)
  if (!env_name %in% valid_envs) {
    abort(c(
      "Environment not found",
      "x" = paste("Invalid environment:", env_name),
      "i" = "Available environments:",
      set_names(paste("", valid_envs), rep("*", length(valid_envs)))
    ), call = NULL)
  }

  # Resolve dependencies to get all features
  deps <- resolve_dependencies(env_name, config, args = args)

  # Collect all packages from all features
  all_packages <- character()
  for (dep in deps) {
    pkgs <- get_feature_packages(dep, config)
    if (length(pkgs) > 0) {
      all_packages <- c(all_packages, names(pkgs))
    }
  }

  # Output one package per line (for easy bash consumption)
  for (pkg in unique(all_packages)) {
    cat(pkg, "\n", sep = "")
  }
}

# =============================================================================
# Configuration Management
# =============================================================================

#' Read and validate rpixi.toml
#'
#' Reads the rpixi.toml file, parses it, and validates its structure.
#'
#' @param path Character. Path to rpixi.toml file
#' @param args List. Parsed arguments (for logging verbosity)
#' @return List. Parsed TOML configuration
read_requirements <- function(path, args) {
  if (!file.exists(path)) {
    abort(c(
      "rpixi.toml file not found",
      "x" = paste("Path:", path),
      "i" = "Specify a different path with --manifest-path"
    ), call = caller_env())
  }

  # Parse TOML
  config <- tryCatch(
    RcppTOML::parseTOML(path),
    error = function(e) {
      abort(c(
        "Invalid TOML syntax",
        "x" = e$message,
        "i" = paste("File:", path)
      ), call = caller_env())
    }
  )

  # Validate structure
  if (is_null(config$project)) {
    abort(c(
      "Invalid rpixi.toml structure",
      "x" = "Missing [project] section",
      "i" = "See rpixi.toml format documentation"
    ), call = caller_env())
  }

  if (is_null(config$environments)) {
    abort(c(
      "Invalid rpixi.toml structure",
      "x" = "Missing [environments] section",
      "i" = "At least one environment must be defined"
    ), call = caller_env())
  }

  log_verbose(
    paste("Loaded", length(config$environments), "environments"),
    args$verbose, args$quiet
  )

  config
}

#' Get all valid environment names (including implicit "default")
#'
#' Returns a vector of all valid environment names, including the implicit
#' "default" environment which is constructed from top-level [dependencies].
#'
#' @param config List. Parsed rpixi.toml configuration
#' @return Character vector of environment names
get_valid_environments <- function(config) {
  c("default", names(config$environments))
}

# =============================================================================
# Package Management
# =============================================================================

#' Get packages for a specific feature or base dependencies
#'
#' Retrieves package specifications from either the top-level [dependencies]
#' section (for "base") or a [feature.NAME.dependencies] section.
#'
#' @param feature_name Character. Name of feature ("base" for top-level dependencies)
#' @param config List. Parsed rpixi.toml configuration
#' @return List of package specifications
get_feature_packages <- function(feature_name, config) {
  if (feature_name == "base") {
    # Base dependencies
    deps <- if (is.null(config$dependencies)) list() else config$dependencies
    return(deps)
  }

  # Feature dependencies
  feature_key <- paste0("feature.", feature_name, ".dependencies")
  parts <- strsplit(feature_key, "\\.")[[1]]

  # Navigate nested list
  obj <- config
  for (part in parts) {
    if (is.null(obj[[part]])) {
      return(list())
    }
    obj <- obj[[part]]
  }

  obj
}

#' Check if a package is installed
#'
#' @param pkg_name Character. Name of package to check
#' @return Logical. TRUE if package is installed
is_package_installed <- function(pkg_name) {
  requireNamespace(pkg_name, quietly = TRUE)
}

#' Install a single package
#'
#' Installs a package based on its specification. Handles CRAN packages,
#' GitHub packages, and custom repository packages.
#'
#' @param pkg_name Character. Name of package to install
#' @param pkg_spec Character or List. Package specification (version string or complex spec)
#' @param args List. Parsed arguments (for install options and logging)
#' @return List with 'installed' and 'skipped' counts
install_package <- function(pkg_name, pkg_spec, args) {
  # Determine if we should skip
  skip <- FALSE
  if (args$skip_installed && !args$force) {
    # Check for force flag in package spec
    force_install <- if (is.list(pkg_spec) && !is_null(pkg_spec$force)) pkg_spec$force else FALSE

    if (!force_install && is_package_installed(pkg_name)) {
      skip <- TRUE
    }
  }

  if (skip) {
    log_info(paste0("  [SKIP] ", pkg_name, " (already installed)"), args$quiet)
    return(list(installed = FALSE, skipped = TRUE))
  }

  # Determine package source and install
  if (is_string(pkg_spec)) {
    # Simple version constraint string - CRAN package
    log_info(paste0("  [INSTALL] ", pkg_name, " ", pkg_spec, " from CRAN"), args$quiet)
    if (!args$dry_run) {
      tryCatch(
        remotes::install_version(
          pkg_name,
          version = pkg_spec,
          upgrade = "never",
          quiet = args$quiet
        ),
        error = function(e) {
          abort(c(
            "Package installation failed",
            "x" = paste("Failed to install", pkg_name, "from CRAN"),
            "i" = e$message
          ), call = NULL)
        }
      )
    }
  } else if (is.list(pkg_spec)) {
    # Complex specification
    if (!is_null(pkg_spec$github)) {
      # GitHub package
      repo_spec <- pkg_spec$github

      # Add git ref if specified
      if (!is_null(pkg_spec$tag)) {
        repo_spec <- paste0(repo_spec, "@", pkg_spec$tag)
      } else if (!is_null(pkg_spec$branch)) {
        repo_spec <- paste0(repo_spec, "@", pkg_spec$branch)
      } else if (!is_null(pkg_spec$rev)) {
        repo_spec <- paste0(repo_spec, "@", pkg_spec$rev)
      }

      log_info(paste0("  [INSTALL] ", pkg_name, " from GitHub: ", repo_spec), args$quiet)
      if (!args$dry_run) {
        tryCatch(
          remotes::install_github(repo_spec, upgrade = "never", quiet = args$quiet),
          error = function(e) {
            abort(c(
              "Package installation failed",
              "x" = paste("Failed to install", pkg_name, "from GitHub:", repo_spec),
              "i" = e$message
            ), call = NULL)
          }
        )
      }
    } else if (!is_null(pkg_spec$version)) {
      # CRAN with version (optionally with custom repo)
      force_str <- if (!is_null(pkg_spec$force) && pkg_spec$force) " (forced)" else ""

      # Build repos list
      repos <- if (!is_null(pkg_spec$repos)) {
        c(pkg_spec$repos, getOption("repos"))
      } else {
        getOption("repos")
      }

      repo_str <- if (!is_null(pkg_spec$repos)) {
        paste0(" from ", pkg_spec$repos)
      } else {
        " from CRAN"
      }

      log_info(
        paste0("  [INSTALL] ", pkg_name, " ", pkg_spec$version, repo_str, force_str),
        args$quiet
      )
      if (!args$dry_run) {
        tryCatch(
          remotes::install_version(
            pkg_name,
            version = pkg_spec$version,
            repos = repos,
            upgrade = "never",
            quiet = args$quiet
          ),
          error = function(e) {
            abort(c(
              "Package installation failed",
              "x" = paste("Failed to install", pkg_name, pkg_spec$version, repo_str),
              "i" = e$message
            ), call = NULL)
          }
        )
      }
    } else if (!is_null(pkg_spec$repos)) {
      # Custom repo without version - install latest from custom repo
      force_str <- if (!is_null(pkg_spec$force) && pkg_spec$force) " (forced)" else ""

      # Build repos list with custom repo first
      repos <- c(pkg_spec$repos, getOption("repos"))

      log_info(
        paste0("  [INSTALL] ", pkg_name, " from ", pkg_spec$repos, force_str),
        args$quiet
      )
      if (!args$dry_run) {
        tryCatch(
          remotes::install_cran(
            pkg_name,
            repos = repos,
            upgrade = "never",
            quiet = args$quiet
          ),
          error = function(e) {
            abort(c(
              "Package installation failed",
              "x" = paste("Failed to install", pkg_name, "from", pkg_spec$repos),
              "i" = e$message
            ), call = NULL)
          }
        )
      }
    } else {
      # Unknown spec - this shouldn't happen with valid TOML
      abort(c(
        "Invalid package specification",
        "x" = paste("Package", pkg_name, "has unknown specification format"),
        "i" = paste(
          "Expected 'version' (optionally with 'repos'), 'repos',",
          "or 'github' field in rpixi.toml"
        )
      ), call = caller_env())
    }
  } else {
    # Invalid spec type - this shouldn't happen with valid TOML
    abort(c(
      "Invalid package specification type",
      "x" = paste("Package", pkg_name, "must be a string or table"),
      "i" = "Check rpixi.toml format"
    ), call = caller_env())
  }

  list(installed = TRUE, skipped = FALSE)
}

#' Categorize package by installation type
#'
#' @param pkg_spec Character or List. Package specification
#' @return Character. One of: "cran_unversioned", "cran_versioned", "cran_custom_repo", "github"
categorize_package_type <- function(pkg_spec) {
  if (is_string(pkg_spec)) {
    # String specs with content are versioned
    if (nzchar(pkg_spec) && pkg_spec != "*") {
      return("cran_versioned")
    } else {
      return("cran_unversioned")
    }
  } else if (is.list(pkg_spec)) {
    if (!is_null(pkg_spec$github)) {
      return("github")
    } else if (!is_null(pkg_spec$repos)) {
      # Has custom repo - must install individually to apply repo correctly
      # Don't batch these packages as the custom repo should only apply to this package
      return("cran_custom_repo")
    } else if (!is_null(pkg_spec$version) && nzchar(pkg_spec$version) && pkg_spec$version != "*") {
      # Has explicit non-wildcard version
      return("cran_versioned")
    } else {
      # No version, no custom repo - can be batched
      return("cran_unversioned")
    }
  }

  # Invalid package specification type
  abort(c(
    "Invalid package specification type",
    "x" = "Package specification must be a string or list",
    "i" = "Check rpixi.toml format"
  ), call = caller_env())
}

#' Batch install non-versioned CRAN packages
#'
#' @param pkg_list Named list. Package names as names, specs as values
#' @param args List. Parsed arguments (for install options and logging)
#' @return List with 'installed' and 'skipped' counts
install_cran_batch <- function(pkg_list, args) {
  if (length(pkg_list) == 0) {
    return(list(installed = 0, skipped = 0))
  }

  pkg_names <- names(pkg_list)

  # Filter out already-installed packages if skip_installed is enabled
  to_install_names <- pkg_names
  skipped <- 0

  if (args$skip_installed && !args$force) {
    to_install_names <- Filter(function(pkg) !is_package_installed(pkg), pkg_names)
    skipped <- length(pkg_names) - length(to_install_names)

    # Log skipped packages
    if (skipped > 0) {
      skipped_names <- setdiff(pkg_names, to_install_names)
      for (pkg in skipped_names) {
        log_info(paste0("  [SKIP] ", pkg, " (already installed)"), args$quiet)
      }
    }
  }

  # Install remaining packages
  if (length(to_install_names) > 0) {
    # Note: Packages with custom repos are installed individually,
    # so this batch only contains regular CRAN packages

    log_info(
      paste0(
        "  [INSTALL] Batch installing ",
        length(to_install_names),
        " packages from CRAN"
      ),
      args$quiet
    )
    if (!args$dry_run) {
      # Capture warnings during installation
      install_warnings <- list()
      tryCatch(
        withCallingHandlers(
          remotes::install_cran(
            to_install_names,
            repos = getOption("repos"),
            upgrade = "never",
            quiet = args$quiet
          ),
          warning = function(w) {
            install_warnings[[length(install_warnings) + 1]] <<- w$message
            invokeRestart("muffleWarning")
          }
        ),
        error = function(e) {
          # Show captured warnings
          if (length(install_warnings) > 0) {
            cat("\nInstallation warnings:\n", file = stderr())
            for (w in install_warnings) {
              cat("  ", w, "\n", sep = "", file = stderr())
            }
          }
          abort(c(
            "Batch package installation failed",
            "x" = paste(
              "Failed to install one or more packages from:",
              paste(to_install_names, collapse = ", ")
            ),
            "i" = e$message
          ), call = NULL)
        }
      )
    }
  }

  list(installed = length(to_install_names), skipped = skipped)
}

#' Install packages for an environment
#'
#' Installs all packages required by an environment, following its dependency
#' chain and installing packages from all resolved features.
#'
#' @param env_name Character. Name of environment to install
#' @param config List. Parsed rpixi.toml configuration
#' @param args List. Parsed arguments (for install options and logging)
#' @return List with total 'installed' and 'skipped' counts
install_environment <- function(env_name, config, args) {
  # Resolve dependencies
  deps <- resolve_dependencies(env_name, config, args = args)
  log_info(paste("Resolved dependencies:", paste(deps, collapse = ", ")), args$quiet)

  # Collect all packages from all features
  all_packages <- list()
  for (dep in deps) {
    pkgs <- get_feature_packages(dep, config)
    if (length(pkgs) > 0) {
      # Merge packages, avoiding duplicates
      for (pkg_name in names(pkgs)) {
        if (!pkg_name %in% names(all_packages)) {
          all_packages[[pkg_name]] <- pkgs[[pkg_name]]
        }
      }
    }
  }

  if (length(all_packages) == 0) {
    log_info("No packages to install", args$quiet)
    return(list(installed = 0, skipped = 0))
  }

  # Categorize packages by type and force flag
  cran_unversioned_normal <- list()  # named list of package specs
  cran_unversioned_forced <- list()  # named list of package specs
  other_packages <- list()  # list of lists: list(name, spec, forced)

  for (pkg_name in names(all_packages)) {
    pkg_spec <- all_packages[[pkg_name]]
    is_forced <- (is.list(pkg_spec) && !is_null(pkg_spec$force) && pkg_spec$force) || args$force
    pkg_type <- categorize_package_type(pkg_spec)

    if (pkg_type == "cran_unversioned") {
      if (is_forced) {
        cran_unversioned_forced[[pkg_name]] <- pkg_spec
      } else {
        cran_unversioned_normal[[pkg_name]] <- pkg_spec
      }
    } else {
      # All other types: install sequentially (versioned CRAN, GitHub)
      other_packages[[length(other_packages) + 1]] <- list(
        name = pkg_name,
        spec = pkg_spec,
        forced = is_forced
      )
    }
  }

  # Install packages
  total_installed <- 0
  total_skipped <- 0

  # Batch install non-versioned CRAN packages (non-forced)
  if (length(cran_unversioned_normal) > 0) {
    log_info(
      paste0(
        "\nBatch installing ",
        length(cran_unversioned_normal),
        " non-versioned CRAN packages..."
      ),
      args$quiet
    )
    result <- install_cran_batch(cran_unversioned_normal, args)
    total_installed <- total_installed + result$installed
    total_skipped <- total_skipped + result$skipped
  }

  # Batch install non-versioned CRAN packages (forced)
  if (length(cran_unversioned_forced) > 0) {
    log_info(
      paste0(
        "\nBatch installing ",
        length(cran_unversioned_forced),
        " non-versioned CRAN packages (forced)..."
      ),
      args$quiet
    )
    # Set force flag temporarily
    args_forced <- args
    args_forced$force <- TRUE
    result <- install_cran_batch(cran_unversioned_forced, args_forced)
    total_installed <- total_installed + result$installed
    total_skipped <- total_skipped + result$skipped
  }

  # Install other packages sequentially (versioned CRAN, GitHub)
  if (length(other_packages) > 0) {
    log_info(
      paste0(
        "\nInstalling ",
        length(other_packages),
        " packages (versioned/GitHub)..."
      ),
      args$quiet
    )

    for (pkg_info in other_packages) {
      pkg_name <- pkg_info$name
      pkg_spec <- pkg_info$spec

      # Set force flag if needed
      if (pkg_info$forced && !args$force) {
        args_pkg <- args
        args_pkg$force <- TRUE
      } else {
        args_pkg <- args
      }

      result <- tryCatch(
        install_package(pkg_name, pkg_spec, args_pkg),
        error = function(e) {
          abort(c(
            "Package installation failed",
            "x" = paste("Failed to install", pkg_name),
            "i" = e$message
          ), call = NULL)
        }
      )

      if (result$installed) total_installed <- total_installed + 1
      if (result$skipped) total_skipped <- total_skipped + 1
    }
  }

  list(installed = total_installed, skipped = total_skipped)
}

# =============================================================================
# Pak Script Generation
# =============================================================================

#' Convert package specification to pak reference format
#'
#' Transforms rpixi.toml package specs into pak-compatible package references.
#'
#' @param pkg_name Character. Name of the package
#' @param pkg_spec Character or List. Package specification from rpixi.toml
#' @return List with 'pak_ref' (character) and 'custom_repo' (character or NULL)
transform_to_pak_ref <- function(pkg_name, pkg_spec) {
  # Simple string specs (CRAN packages)
  if (is_string(pkg_spec)) {
    # Ignore version constraints for pak - it handles versions automatically
    return(list(pak_ref = pkg_name, custom_repo = NULL))
  }

  # Complex specs (lists)
  if (is.list(pkg_spec)) {
    # GitHub packages
    if (!is_null(pkg_spec$github)) {
      repo <- pkg_spec$github
      # Add ref (tag, branch, or rev) if specified
      ref <- pkg_spec$tag %||% pkg_spec$branch %||% pkg_spec$rev
      if (!is_null(ref)) {
        pak_ref <- paste0(repo, "@", ref)
      } else {
        pak_ref <- repo
      }
      return(list(pak_ref = pak_ref, custom_repo = NULL))
    }

    # Custom repo packages
    if (!is_null(pkg_spec$repos)) {
      return(list(pak_ref = pkg_name, custom_repo = pkg_spec$repos))
    }

    # CRAN with explicit version (ignore version for pak)
    if (!is_null(pkg_spec$version)) {
      return(list(pak_ref = pkg_name, custom_repo = NULL))
    }

    # Fallback for other list specs (e.g., just force = true)
    return(list(pak_ref = pkg_name, custom_repo = NULL))
  }

  # Unknown spec type
  abort(c(
    "Invalid package specification",
    "x" = paste("Package", pkg_name, "has unknown specification format"),
    "i" = "Expected string or list with 'github', 'repos', or 'version' field"
  ), call = caller_env())
}

#' Generate pak installer script for an environment
#'
#' Creates a self-contained R script that installs all packages for an
#' environment using the pak package manager.
#'
#' @param env_name Character. Name of environment to generate script for
#' @param config List. Parsed rpixi.toml configuration
#' @param args List. Parsed arguments (for logging verbosity)
#' @return Character vector containing the complete script
generate_pak_script <- function(env_name, config, args) {
  # Resolve dependencies to get all features
  deps <- resolve_dependencies(env_name, config, args = args)
  log_verbose(
    paste("  Resolved dependencies:", paste(deps, collapse = ", ")),
    args$verbose, args$quiet
  )

  # Collect packages from all features, tracking which feature each came from
  standard_packages <- list()  # list of list(name, pak_ref, feature)
  custom_repo_packages <- list()  # list of list(name, pak_ref, repo, feature)

  for (dep in deps) {
    pkgs <- get_feature_packages(dep, config)
    if (length(pkgs) > 0) {
      for (pkg_name in names(pkgs)) {
        # Skip if already added (first occurrence wins)
        already_added <- any(vapply(
          c(standard_packages, custom_repo_packages),
          function(p) p$name == pkg_name,
          logical(1)
        ))
        if (already_added) next

        pkg_spec <- pkgs[[pkg_name]]
        transformed <- transform_to_pak_ref(pkg_name, pkg_spec)

        if (is_null(transformed$custom_repo)) {
          standard_packages[[length(standard_packages) + 1]] <- list(
            name = pkg_name,
            pak_ref = transformed$pak_ref,
            feature = dep
          )
        } else {
          custom_repo_packages[[length(custom_repo_packages) + 1]] <- list(
            name = pkg_name,
            pak_ref = transformed$pak_ref,
            repo = transformed$custom_repo,
            feature = dep
          )
        }
      }
    }
  }

  log_verbose(
    paste("  Standard packages:", length(standard_packages)),
    args$verbose, args$quiet
  )
  log_verbose(
    paste("  Custom repo packages:", length(custom_repo_packages)),
    args$verbose, args$quiet
  )

  # Build script
  script_lines <- character()

  # Header
  script_lines <- c(script_lines, build_script_header(
    env_name,
    length(standard_packages) + length(custom_repo_packages),
    args$manifest_path
  ))

  # Pak bootstrap
  script_lines <- c(script_lines, "", build_pak_bootstrap())

  # Standard packages install
  if (length(standard_packages) > 0) {
    script_lines <- c(script_lines, "", build_pak_install_code(
      standard_packages, deps, "main"
    ))
  }

  # Custom repo packages (each in separate install block)
  for (pkg in custom_repo_packages) {
    script_lines <- c(script_lines, "", build_custom_repo_install(pkg))
  }

  # Footer
  script_lines <- c(script_lines, "", 'message("Installation complete!")')

  script_lines
}

#' Build script header with metadata
#'
#' @param env_name Character. Environment name
#' @param pkg_count Integer. Total number of packages
#' @param manifest_path Character. Path to rpixi.toml
#' @return Character vector of header lines
build_script_header <- function(env_name, pkg_count, manifest_path) {
  c(
    "#!/usr/bin/env Rscript",
    "",
    "#' CourseKata R Package Installer",
    "#'",
    paste0("#' This script installs R packages for the ", env_name, " environment"),
    "#' using the pak package manager.",
    "#'",
    paste0("#' Generated by rpixi pakgen v", VERSION),
    paste0("#' Environment: ", env_name),
    paste0("#' Package count: ", pkg_count),
    paste0("#' Source: ", manifest_path),
    "#'",
    "#' Usage:",
    paste0("#'   Rscript ", env_name, ".R"),
    "#'   # or",
    paste0("#'   ./", env_name, ".R")
  )
}

#' Build pak bootstrap code
#'
#' @return Character vector of bootstrap code lines
build_pak_bootstrap <- function() {
  c(
    "# Bootstrap pak package manager",
    'if (!requireNamespace("pak", quietly = TRUE)) {',
    '  message("Installing pak...")',
    '  install.packages("pak", repos = "https://cloud.r-project.org/")',
    "}"
  )
}

#' Build pak::pkg_install code for standard packages
#'
#' @param packages List of package info lists (name, pak_ref, feature)
#' @param features Character vector of features in order
#' @param block_name Character. Name for this install block (for logging)
#' @return Character vector of installation code lines
build_pak_install_code <- function(packages, features, block_name) {
  pkg_count <- length(packages)

  lines <- c(
    paste0("# Install packages (", pkg_count, " total)"),
    paste0('message("Installing ', pkg_count, ' packages...")'),
    "pak::pkg_install(",
    "  c("
  )

  # Group packages by feature for better readability
  current_feature <- NULL
  for (i in seq_along(packages)) {
    pkg <- packages[[i]]

    # Add feature comment if feature changed
    if (is_null(current_feature) || pkg$feature != current_feature) {
      current_feature <- pkg$feature
      feature_label <- if (current_feature == "base") "Base dependencies" else paste0("Feature: ", current_feature)
      if (i == 1) {
        lines <- c(lines, paste0("    # ", feature_label))
      } else {
        lines <- c(lines, "", paste0("    # ", feature_label))
      }
    }

    # Add package reference
    comma <- if (i < pkg_count) "," else ""
    lines <- c(lines, paste0('    "', pkg$pak_ref, '"', comma))
  }

  lines <- c(lines,
    "  ),",
    "  upgrade = FALSE",
    ")"
  )

  lines
}

#' Build installation code for a custom repo package
#'
#' @param pkg List with name, pak_ref, repo, feature
#' @return Character vector of installation code lines
build_custom_repo_install <- function(pkg) {
  c(
    paste0("# Custom repo: ", pkg$name, " from ", pkg$repo),
    paste0('message("Installing ', pkg$name, ' from custom repository...")'),
    paste0('options(repos = c(getOption("repos"), "', pkg$repo, '"))'),
    paste0('pak::pkg_install("', pkg$pak_ref, '", upgrade = FALSE)')
  )
}

# =============================================================================
# Utility Functions
# =============================================================================

#' Log informational message
#'
#' @param msg Character. Message to log
#' @param quiet Logical. If TRUE, suppress output
log_info <- function(msg, quiet = FALSE) {
  if (!quiet) inform(msg)
}

#' Log verbose message
#'
#' Only displays if verbose mode is enabled and quiet mode is disabled.
#'
#' @param msg Character. Message to log
#' @param verbose Logical. If TRUE, message is eligible for display
#' @param quiet Logical. If TRUE, suppress output regardless of verbose
log_verbose <- function(msg, verbose = FALSE, quiet = FALSE) {
  if (verbose && !quiet) inform(msg)
}


# =============================================================================
# Script Execution
# =============================================================================

# Run main when script is executed (not when sourced)
if (!interactive()) {
  main()
}

variable "REGISTRY" {
  default = "ghcr.io/coursekata"
}

variable "CACHE_REGISTRY" {
  default = "${REGISTRY}/cache"
}

variable "TAGS" {
  default = "test"
}

function "tags" {
  # Construct a list of tags for the given image name and tag suffix
  params = [name, suffix]
  result = [
    for tag in split(",", replace("${TAGS}", "\n", ",")) :
      "${REGISTRY}/${name}:${tag}${suffix}"
  ]
}

function "cache-to" {
  # Construct a list of cache-to strings for the given image name and tag suffix
  params = [name, suffix]
  result = [
    for tag in split(",", replace("${TAGS}", "\n", ",")) :
      "type=registry,ref=${CACHE_REGISTRY}/${name}:${tag}${suffix},mode=max"
  ]
}

function "cache-from" {
  # Construct a list of cache-from strings for the given image name and tag suffix
  params = [name, suffix]
  result = concat(
    flatten([for r in ["${REGISTRY}", "${CACHE_REGISTRY}"] :
      [ for i in ["foundation", "base", "${name}"] : "type=registry,ref=${r}/${i}:latest" ]
    ]),
    flatten([for r in ["${REGISTRY}", "${CACHE_REGISTRY}"] :
      flatten([for t in split(",", replace("${TAGS}", "\n", ",")) :
        [ for i in ["foundation", "base", "${name}"] : "type=registry,ref=${r}/${i}:${t}" ]
      ])
    ]),
    flatten([for r in ["${REGISTRY}", "${CACHE_REGISTRY}"] :
      flatten([for t in split(",", replace("${TAGS}", "\n", ",")) :
        [ for i in ["foundation", "base", "${name}"] : "type=registry,ref=${r}/${i}:${t}${suffix}" ]
      ])
    ]),
  )
}


# ------------------------------------------------------------------------------
# Common partials
# ------------------------------------------------------------------------------
# dummy target that receives extra labels from the GitHub Action
target "docker-metadata-action" {}

target "_common" {
  inherits = ["docker-metadata-action"]
  context = "."
  platforms = ["linux/amd64", "linux/arm64"]
  secret = ["type=env,id=GITHUB_TOKEN"]
  labels = {
    "org.opencontainers.image.base.name": "docker.io/library/ubuntu:noble",
    "org.opencontainers.image.licenses": "BSD-3-Clause",
    "org.opencontainers.image.source": "https://github.com/coursekata/docker-stacks",
    "org.opencontainers.image.vendor": "CourseKata",
    "org.opencontainers.image.authors": "Adam Blake <adam@coursekata.org>"
  }
}

target "_amd64" {
  platforms = ["linux/amd64"]
}

target "_arm64" {
  platforms = ["linux/arm64"]
}

target "_multiarch" {
  platforms = ["linux/amd64", "linux/arm64"]
  cache-to = ["type=inline"]
}


# ------------------------------------------------------------------------------
# Base Images
# ------------------------------------------------------------------------------
group "base" {
  targets = ["foundation", "base"]
}

group "base-amd64" {
  targets = ["foundation-amd64", "base-amd64"]
}

group "base-arm64" {
  targets = ["foundation-arm64", "base-arm64"]
}

target "_foundation" {
  inherits = ["_common"]
  labels = {
    "org.opencontainers.image.title": "CourseKata Foundation",
    "org.opencontainers.image.description": "A minimal set of common tools and libraries that all CourseKata images depend on",
  }
  dockerfile = "dockerfiles/base.Dockerfile"
  target = "foundation"
}

target "foundation-amd64" {
  inherits = ["_foundation", "_amd64"]
  tags = tags("foundation", "-amd64")
  cache-to = cache-to("foundation", "-amd64")
  cache-from = cache-from("foundation", "-amd64")
}

target "foundation-arm64" {
  inherits = ["_foundation", "_arm64"]
  tags = tags("foundation", "-arm64")
  cache-to = cache-to("foundation", "-arm64")
  cache-from = cache-from("foundation", "-arm64")
}

target "foundation" {
  inherits = ["_foundation", "_multiarch"]
  tags = tags("foundation", "")
  cache-from = concat(cache-from("foundation", "-amd64"), cache-from("foundation", "-arm64"))
}

target "_base" {
  inherits = ["_foundation"]
  labels = {
    "org.opencontainers.image.title": "CourseKata Base",
    "org.opencontainers.image.description": "The set of common tools and libraries that most CourseKata images depend on",
  }
  dockerfile = "dockerfiles/base.Dockerfile"
  target = "final"
}

target "base-amd64" {
  inherits = ["_base", "_amd64"]
  tags = tags("base", "-amd64")
  cache-to = cache-to("base", "-amd64")
  cache-from = cache-from("base", "-amd64")
}

target "base-arm64" {
  inherits = ["_base", "_arm64"]
  tags = tags("base", "-arm64")
  cache-to = cache-to("base", "-arm64")
  cache-from = cache-from("base", "-arm64")
}

target "base" {
  inherits = ["_base", "_multiarch"]
  tags = tags("base", "")
  cache-from = concat(cache-from("base", "-amd64"), cache-from("base", "-arm64"))
}


# ------------------------------------------------------------------------------
# Main Images
# ------------------------------------------------------------------------------
group "main" {
  targets = ["base-r", "essentials", "r", "datascience", "ckhub"]
}

group "main-amd64" {
  targets = ["base-r-amd64", "essentials-amd64", "r-amd64", "datascience-amd64", "ckhub-amd64"]
}

group "main-arm64" {
  targets = ["base-r-arm64", "essentials-arm64", "r-arm64", "datascience-arm64", "ckhub-arm64"]
}

target "_main-amd64" {
  inherits = ["_common", "_amd64"]
  dockerfile = "dockerfiles/main.Dockerfile"
  contexts = { "parent-target" = "target:base-amd64" }
  args = { PARENT = "parent-target" }
}

target "_main-arm64" {
  inherits = ["_common", "_arm64"]
  dockerfile = "dockerfiles/main.Dockerfile"
  contexts = { "parent-target" = "target:base-arm64" }
  args = { PARENT = "parent-target" }
}

target "_main-multiarch" {
  inherits = ["_common", "_multiarch"]
  dockerfile = "dockerfiles/main.Dockerfile"
  contexts = { "parent-target" = "target:base" }
  args = { PARENT = "parent-target" }
}

target "_base-r" {
  labels = {
    "org.opencontainers.image.title": "CourseKata Base R",
    "org.opencontainers.image.description": "The set of common tools and libraries that most CourseKata R images depend on",
  }
  args = { PIXI_ENV = "base-r" }
}

target "base-r-amd64" {
  inherits = ["_main-amd64", "_base-r"]
  tags = tags("base-r", "-amd64")
  cache-to = cache-to("base-r", "-amd64")
  cache-from = cache-from("base-r", "-amd64")
}

target "base-r-arm64" {
  inherits = ["_main-arm64", "_base-r"]
  tags = tags("base-r", "-arm64")
  cache-to = cache-to("base-r", "-arm64")
  cache-from = cache-from("base-r", "-arm64")
}

target "base-r" {
  inherits = ["_main-multiarch", "_base-r"]
  tags = tags("base-r", "")
  cache-from = concat(cache-from("base-r", "-amd64"), cache-from("base-r", "-arm64"))
}

target "_essentials" {
  labels = {
    "org.opencontainers.image.title": "CourseKata Essentials",
    "org.opencontainers.image.description": "The libraries essential for working through CourseKata textbooks",
  }
  args = { PIXI_ENV = "essentials" }
}

target "essentials-amd64" {
  inherits = ["_main-amd64", "_essentials"]
  tags = tags("essentials", "-amd64")
  cache-to = cache-to("essentials", "-amd64")
  cache-from = cache-from("essentials", "-amd64")
}

target "essentials-arm64" {
  inherits = ["_main-arm64", "_essentials"]
  tags = tags("essentials", "-arm64")
  cache-to = cache-to("essentials", "-arm64")
  cache-from = cache-from("essentials", "-arm64")
}

target "essentials" {
  inherits = ["_main-multiarch", "_essentials"]
  tags = tags("essentials", "")
  cache-from = concat(cache-from("essentials", "-amd64"), cache-from("essentials", "-arm64"))
}

target "_r" {
  labels = {
    "org.opencontainers.image.title": "CourseKata R",
    "org.opencontainers.image.description": "A full-featured R environment for working through CourseKata lessons",
  }
  args = { PIXI_ENV = "r" }
}

target "r-amd64" {
  inherits = ["_main-amd64", "_r"]
  tags = tags("r", "-amd64")
  cache-to = cache-to("r", "-amd64")
  cache-from = cache-from("r", "-amd64")
}

target "r-arm64" {
  inherits = ["_main-arm64", "_r"]
  tags = tags("r", "-arm64")
  cache-to = cache-to("r", "-arm64")
  cache-from = cache-from("r", "-arm64")
}

target "r" {
  inherits = ["_main-multiarch", "_r"]
  tags = tags("r", "")
  cache-from = concat(cache-from("r", "-amd64"), cache-from("r", "-arm64"))
}

target "_datascience" {
  labels = {
    "org.opencontainers.image.title": "CourseKata Data Science",
    "org.opencontainers.image.description": "A full-featured data science environment (R + Python) for working through CourseKata lessons",
  }
  args = { PIXI_ENV = "datascience" }
}

target "datascience-amd64" {
  inherits = ["_main-amd64", "_datascience"]
  tags = tags("datascience", "-amd64")
  cache-to = cache-to("datascience", "-amd64")
  cache-from = cache-from("datascience", "-amd64")
}

target "datascience-arm64" {
  inherits = ["_main-arm64", "_datascience"]
  tags = tags("datascience", "-arm64")
  cache-to = cache-to("datascience", "-arm64")
  cache-from = cache-from("datascience", "-arm64")
}

target "datascience" {
  inherits = ["_main-multiarch", "_datascience"]
  tags = tags("datascience", "")
  cache-from = concat(cache-from("datascience", "-amd64"), cache-from("datascience", "-arm64"))
}

target "_ckhub" {
  labels = {
    "org.opencontainers.image.title": "CourseKata CKHub",
    "org.opencontainers.image.description": "The standard CKHub environment (the data science environment with CKHub extensions)",
  }
  args = { PIXI_ENV = "ckhub" }
}

target "ckhub-amd64" {
  inherits = ["_main-amd64", "_ckhub"]
  tags = tags("ckhub", "-amd64")
  cache-to = cache-to("ckhub", "-amd64")
  cache-from = cache-from("ckhub", "-amd64")
}

target "ckhub-arm64" {
  inherits = ["_main-arm64", "_ckhub"]
  tags = tags("ckhub", "-arm64")
  cache-to = cache-to("ckhub", "-arm64")
  cache-from = cache-from("ckhub", "-arm64")
}

target "ckhub" {
  inherits = ["_main-multiarch", "_ckhub"]
  tags = tags("ckhub", "")
  cache-from = concat(cache-from("ckhub", "-amd64"), cache-from("ckhub", "-arm64"))
}

# ------------------------------------------------------------------------------
# Images with minimal utilities
#
# The ckcode and Deepnote images don't need all the extra utilities. These are
# used more as code execution engines rather than the full notebook experience.
# Additionally, they only need to run in the `amd64` architecture.
# ------------------------------------------------------------------------------
group "minimal" {
  targets = ["ckcode", "deepnote-base-r", "deepnote-essentials", "deepnote-r", "deepnote-datascience"]
}

target "_minimal" {
  inherits = ["_common", "_amd64"]
  dockerfile = "dockerfiles/main.Dockerfile"
  contexts = { "parent-target" = "target:base-amd64" }
  args = { PARENT = "parent-target" }
}

target "ckcode" {
  inherits = ["_minimal"]
  labels = {
    "org.opencontainers.image.title": "CourseKata CKCode",
    "org.opencontainers.image.description": "A minimal environment for running CourseKata code execution engines",
  }
  args = { PIXI_ENV = "ckcode" }
  tags = tags("ckcode", "")
  cache-to = cache-to("ckcode", "")
  cache-from = cache-from("ckcode", "")
}

target "deepnote-ckcode-r" {
  inherits = ["_minimal"]
  labels = {
    "org.opencontainers.image.title": "CourseKata Deepnote CKCode",
    "org.opencontainers.image.description": "A Deepnote-compatible version of the CKCode image",
  }
  args = { PIXI_ENV = "deepnote-ckcode" }
  tags = tags("deepnote-ckcode", "")
  cache-to = cache-to("deepnote-ckcode", "")
  cache-from = cache-from("deepnote-ckcode", "")
}

target "deepnote-datascience-r" {
  inherits = ["_minimal"]
  labels = {
    "org.opencontainers.image.title": "CourseKata Deepnote Data Science: R",
    "org.opencontainers.image.description": "A Deepnote-compatible version of the the R components of the Data Science image",
  }
  args = { PIXI_ENV = "deepnote-datascience-r", DEFAULT_KERNEL = "ir" }
  tags = tags("deepnote-datascience-r", "")
  cache-to = cache-to("deepnote-datascience-r", "")
  cache-from = cache-from("deepnote-datascience-r", "")
}

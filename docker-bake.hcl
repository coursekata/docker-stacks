variable "REGISTRY" {
  default = "ghcr.io/coursekata"
}

variable "CACHE_REGISTRY" {
  default = "${REGISTRY}/cache"
}

variable "TAG" {
  default = "test"
}

variable "TAG_LIST" {
  default = "test"
}

function "tags" {
  params = [name, suffix]
  result = ["${REGISTRY}/${name}:${TAG}${suffix}"]
}

function "cache-from" {
  params = [name, suffix]
  result = [
    "type=registry,ref=${REGISTRY}/foundation:latest",
    "type=registry,ref=${CACHE_REGISTRY}/foundation:latest",
    "type=registry,ref=${CACHE_REGISTRY}/foundation:${TAG}${suffix}",

    "type=registry,ref=${REGISTRY}/base:latest",
    "type=registry,ref=${CACHE_REGISTRY}/base:latest",
    "type=registry,ref=${CACHE_REGISTRY}/base:${TAG}${suffix}",

    "type=registry,ref=${REGISTRY}/${name}:latest",
    "type=registry,ref=${REGISTRY}/${name}:${TAG}",
    "type=registry,ref=${REGISTRY}/${name}:${TAG}${suffix}",
    "type=registry,ref=${CACHE_REGISTRY}/${name}:latest",
    "type=registry,ref=${CACHE_REGISTRY}/${name}:${TAG}${suffix}",
  ]
}

function "cache-to" {
  params = [name, suffix]
  result = [
    "type=registry,ref=${CACHE_REGISTRY}/${name}:${TAG}${suffix},mode=max"
  ]
}

target "docker-metadata-action" {}

target "default" {
  inherits = ["docker-metadata-action"]
  context = "."
  secret = ["type=env,id=GITHUB_TOKEN"]
  labels = {
    "org.opencontainers.image.base.name": "docker.io/library/ubuntu:noble",
    "org.opencontainers.image.licenses": "BSD-3-Clause",
    "org.opencontainers.image.source": "https://github.com/coursekata/docker-stacks",
    "org.opencontainers.image.vendor": "CourseKata",
    "org.opencontainers.image.authors": "Adam Blake <adam@coursekata.org>"
  }
  tags = [ for t in split(",", "${TAG_LIST}") : "myimage:${t}" ]
}

target "amd64" {
  platforms = ["linux/amd64"]
}

target "arm64" {
  platforms = ["linux/arm64"]
}

target "multiarch" {
  inherits = ["amd64", "arm64"]
  cache-to = ["type=inline"]
}


# ------------------------------------------------------------------------------
# Base Images
# ------------------------------------------------------------------------------
target "foundation--base" {
  inherits = ["default", "labels--foundation"]
  dockerfile = "dockerfiles/base.Dockerfile"
  target = "foundation"
  labels = {
    "org.opencontainers.image.title": "CourseKata Foundation",
    "org.opencontainers.image.description": "A minimal set of common tools and libraries that all CourseKata images depend on",
  }
}

target "foundation-amd64" {
  inherits = ["foundation--base", "amd64"]
  tags = tags("foundation", "-amd64")
  cache-to = cache-to("foundation", "-amd64")
  cache-from = cache-from("foundation", "-amd64")
}

target "foundation-arm64" {
  inherits = ["foundation--base", "arm64"]
  tags = tags("foundation", "-arm64")
  cache-to = cache-to("foundation", "-arm64")
  cache-from = cache-from("foundation", "-arm64")
}

target "foundation" {
  inherits = ["foundation--base", "multiarch"]
  tags = tags("foundation", "")
  cache-from = concat(cache-from("foundation", "-amd64"), cache-from("foundation", "-arm64"))
}


target "base--base" {
  inherits = ["foundation--base", "labels--base"]
  target = "final"
  labels = {
    "org.opencontainers.image.title": "CourseKata Base",
    "org.opencontainers.image.description": "The set of common tools and libraries that most CourseKata images depend on",
  }
}

target "base-amd64" {
  inherits = ["base--base", "amd64"]
  tags = tags("base", "-amd64")
  cache-to = cache-to("base", "-amd64")
  cache-from = cache-from("base", "-amd64")
}

target "base-arm64" {
  inherits = ["base--base", "arm64"]
  tags = tags("base", "-arm64")
  cache-to = cache-to("base", "-arm64")
  cache-from = cache-from("base", "-arm64")
}

target "base" {
  inherits = ["base--base", "multiarch"]
  tags = tags("base", "")
  cache-from = concat(cache-from("base", "-amd64"), cache-from("base", "-arm64"))
}


# ------------------------------------------------------------------------------
# Main Images
# ------------------------------------------------------------------------------
target "main--base-amd64" {
  inherits = ["default", "amd64"]
  dockerfile = "dockerfiles/main.Dockerfile"
  contexts = { "parent-target" = "target:base-amd64" }
  args = { PARENT = "parent-target" }
}

target "main--base-arm64" {
  inherits = ["default", "arm64"]
  dockerfile = "dockerfiles/main.Dockerfile"
  contexts = { "parent-target" = "target:base-arm64" }
  args = { PARENT = "parent-target" }
}

target "main--base-multiarch" {
  inherits = ["default", "multiarch"]
  dockerfile = "dockerfiles/main.Dockerfile"
  contexts = { "parent-target" = "target:base" }
  args = { PARENT = "parent-target" }
}

target "labels--base-r" {
  labels = {
    "org.opencontainers.image.title": "CourseKata Base R",
    "org.opencontainers.image.description": "The set of common tools and libraries that most CourseKata R images depend on",
  }
}

target "base-r-amd64" {
  inherits = ["main--base-amd64", "labels--base-r"]
  args = { PIXI_ENV = "base-r" }
  tags = tags("base-r", "-amd64")
  cache-to = cache-to("base-r", "-amd64")
  cache-from = cache-from("base-r", "-amd64")
}

target "base-r-arm64" {
  inherits = ["main--base-arm64", "labels--base-r"]
  args = { PIXI_ENV = "base-r" }
  tags = tags("base-r", "-arm64")
  cache-to = cache-to("base-r", "-arm64")
  cache-from = cache-from("base-r", "-arm64")
}

target "base-r" {
  inherits = ["main--base-multiarch", "labels--base-r"]
  args = { PIXI_ENV = "base-r" }
  tags = tags("base-r", "")
  cache-to = cache-to("base-r", "")
  cache-from = concat(cache-from("base-r", "-amd64"), cache-from("base-r", "-arm64"))
}

target "labels--essentials" {
  labels = {
    "org.opencontainers.image.title": "CourseKata Essentials",
    "org.opencontainers.image.description": "The libraries essential for working through CourseKata textbooks",
  }
}

target "essentials-amd64" {
  inherits = ["main--base-amd64", "labels--essentials"]
  args = { PIXI_ENV = "essentials" }
  tags = tags("essentials", "-amd64")
  cache-to = cache-to("essentials", "-amd64")
  cache-from = cache-from("essentials", "-amd64")
}

target "essentials-arm64" {
  inherits = ["main--base-arm64", "labels--essentials"]
  args = { PIXI_ENV = "essentials" }
  tags = tags("essentials", "-arm64")
  cache-to = cache-to("essentials", "-arm64")
  cache-from = cache-from("essentials", "-arm64")
}

target "essentials" {
  inherits = ["main--base-multiarch", "labels--essentials"]
  args = { PIXI_ENV = "essentials" }
  tags = tags("essentials", "")
  cache-to = cache-to("essentials", "")
  cache-from = concat(cache-from("essentials", "-amd64"), cache-from("essentials", "-arm64"))
}

target "labels--r" {
  labels = {
    "org.opencontainers.image.title": "CourseKata R",
    "org.opencontainers.image.description": "A full-featured R environment for working through CourseKata lessons",
  }
}

target "r-amd64" {
  inherits = ["main--base-amd64", "labels--r"]
  args = { PIXI_ENV = "r" }
  tags = tags("r", "-amd64")
  cache-to = cache-to("r", "-amd64")
  cache-from = cache-from("r", "-amd64")
}

target "r-arm64" {
  inherits = ["main--base-arm64", "labels--r"]
  args = { PIXI_ENV = "r" }
  tags = tags("r", "-arm64")
  cache-to = cache-to("r", "-arm64")
  cache-from = cache-from("r", "-arm64")
}

target "r" {
  inherits = ["main--base-multiarch", "labels--r"]
  args = { PIXI_ENV = "r" }
  tags = tags("r", "")
  cache-to = cache-to("r", "")
  cache-from = concat(cache-from("r", "-amd64"), cache-from("r", "-arm64"))
}

target "labels--datascience" {
  labels = {
    "org.opencontainers.image.title": "CourseKata Data Science",
    "org.opencontainers.image.description": "A full-featured data science environment (R + Python) for working through CourseKata lessons",
  }
}

target "datascience-amd64" {
  inherits = ["main--base-amd64", "labels--datascience"]
  args = { PIXI_ENV = "datascience" }
  tags = tags("datascience", "-amd64")
  cache-to = cache-to("datascience", "-amd64")
  cache-from = cache-from("datascience", "-amd64")
}

target "datascience-arm64" {
  inherits = ["main--base-arm64", "labels--datascience"]
  args = { PIXI_ENV = "datascience" }
  tags = tags("datascience", "-arm64")
  cache-to = cache-to("datascience", "-arm64")
  cache-from = cache-from("datascience", "-arm64")
}

target "datascience" {
  inherits = ["main--base-multiarch", "labels--datascience"]
  args = { PIXI_ENV = "datascience" }
  tags = tags("datascience", "")
  cache-to = cache-to("datascience", "")
  cache-from = concat(cache-from("datascience", "-amd64"), cache-from("datascience", "-arm64"))
}

target "labels--ckhub" {
  labels = {
    "org.opencontainers.image.title": "CourseKata CKHub",
    "org.opencontainers.image.description": "The standard CKHub environment (the data science environment with CKHub extensions)",
  }
}

target "ckhub-amd64" {
  inherits = ["main--base-amd64", "labels--ckhub"]
  args = { PIXI_ENV = "ckhub" }
  tags = tags("ckhub", "-amd64")
  cache-to = cache-to("ckhub", "-amd64")
  cache-from = cache-from("ckhub", "-amd64")
}

target "ckhub-arm64" {
  inherits = ["main--base-arm64", "labels--ckhub"]
  args = { PIXI_ENV = "ckhub" }
  tags = tags("ckhub", "-arm64")
  cache-to = cache-to("ckhub", "-arm64")
  cache-from = cache-from("ckhub", "-arm64")
}

target "ckhub" {
  inherits = ["main--base-multiarch", "labels--ckhub"]
  args = { PIXI_ENV = "ckhub" }
  tags = tags("ckhub", "")
  cache-to = cache-to("ckhub", "")
  cache-from = concat(cache-from("ckhub", "-amd64"), cache-from("ckhub", "-arm64"))
}

# ------------------------------------------------------------------------------
# Images with minimal utilities
#
# The ckcode and Deepnote images don't need all the extra utilities. These are
# used more as code execution engines rather than the full notebook experience.
# Additionally, they only need to run in the `amd64` architecture.
# ------------------------------------------------------------------------------
target "minimal--base" {
  inherits = ["default", "amd64"]
  dockerfile = "dockerfiles/main.Dockerfile"
  contexts = { "parent-target" = "target:foundation-amd64" }
  args = { PARENT = "parent-target" }
}

target "ckcode" {
  inherits = ["minimal--base"]
  args = { PIXI_ENV = "ckcode" }
  tags = tags("ckcode", "")
  labels = {
    "org.opencontainers.image.title": "CourseKata CKCode",
    "org.opencontainers.image.description": "A minimal environment for running CourseKata code execution engines",
  }
  cache-to = cache-to("ckcode", "")
  cache-from = cache-from("ckcode", "")
}

target "deepnote-base-r" {
  inherits = ["minimal--base"]
  args = { PIXI_ENV = "deepnote-base-r" }
  tags = tags("deepnote-base-r", "")
  labels = {
    "org.opencontainers.image.title": "CourseKata Deepnote Base R",
    "org.opencontainers.image.description": "A Deepnote-compatible version of the CourseKata Base R image",
  }
  cache-to = cache-to("deepnote-base-r", "")
  cache-from = cache-from("deepnote-base-r", "")
}

target "deepnote-essentials" {
  inherits = ["minimal--base"]
  args = { PIXI_ENV = "deepnote-essentials" }
  tags = tags("deepnote-essentials", "")
  labels = {
    "org.opencontainers.image.title": "CourseKata Deepnote Essentials",
    "org.opencontainers.image.description": "A Deepnote-compatible version of the CourseKata Essentials image",
  }
  cache-to = cache-to("deepnote-essentials", "")
  cache-from = cache-from("deepnote-essentials", "")
}

target "deepnote-r" {
  inherits = ["minimal--base"]
  args = { PIXI_ENV = "deepnote-r" }
  tags = tags("deepnote-r", "")
  labels = {
    "org.opencontainers.image.title": "CourseKata Deepnote R",
    "org.opencontainers.image.description": "A Deepnote-compatible version of the CourseKata R image",
  }
  cache-to = cache-to("deepnote-r", "")
  cache-from = cache-from("deepnote-r", "")
}

target "deepnote-datascience" {
  inherits = ["minimal--base"]
  args = { PIXI_ENV = "deepnote-datascience" }
  tags = tags("deepnote-datascience", "")
  labels = {
    "org.opencontainers.image.title": "CourseKata Deepnote Data Science",
    "org.opencontainers.image.description": "A Deepnote-compatible version of the CourseKata Data Science image",
  }
  cache-to = cache-to("deepnote-datascience", "")
  cache-from = cache-from("deepnote-datascience", "")
}

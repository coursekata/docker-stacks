#!/usr/bin/env bash
# Build and push docker-stacks images to ghcr.io, bypassing the wedged workflow.
#
# Mirrors what .github/workflows/build-test-push.yml does: multi-arch build,
# provenance off, pushed under a sha-<commit> tag. Does NOT move `latest` --
# promote that separately once you are happy with the result.
#
#   ./publish-manual.sh                        # datascience-notebook only
#   ./publish-manual.sh r-notebook             # a specific image
#   ./publish-manual.sh base-r-notebook essentials-notebook r-notebook datascience-notebook
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"
IMAGES=("${@:-datascience-notebook}")
SHA="sha-$(git rev-parse --short HEAD)"
export GITHUB_TOKEN="$(gh auth token)"

echo ">>> publishing ${IMAGES[*]} as ${SHA}"

for img in "${IMAGES[@]}"; do
  echo
  echo "=================== ${img} ==================="
  docker buildx build \
    --builder cachexp \
    --platform linux/amd64,linux/arm64 \
    --build-arg "PIXI_ENV=${img}" \
    --secret id=github_token,env=GITHUB_TOKEN \
    --tag "ghcr.io/coursekata/${img}:${SHA}" \
    --provenance=false \
    --push .

  digest=$(docker buildx imagetools inspect "ghcr.io/coursekata/${img}:${SHA}" \
             --format '{{println .Manifest.Digest}}' 2>/dev/null | head -1)
  echo ">>> ${img} published: ghcr.io/coursekata/${img}:${SHA}"
  echo ">>> digest: ${digest}"
done

echo
echo ">>> done. To promote to latest:"
for img in "${IMAGES[@]}"; do
  echo "  docker buildx imagetools create -t ghcr.io/coursekata/${img}:latest ghcr.io/coursekata/${img}:${SHA}"
done

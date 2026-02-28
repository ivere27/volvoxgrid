#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-gpu}"
case "${MODE}" in
  cpu|gpu|all) ;;
  *)
    echo "Usage: $0 [cpu|gpu|all]" >&2
    exit 1
    ;;
esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_NAME="$(basename "${REPO_ROOT}")"
WORKSPACE_ROOT="${WORKSPACE_ROOT:-$(dirname "${REPO_ROOT}")}"
CONTAINER_REPO_ROOT="/workspace/${REPO_NAME}"
IMAGE_TAG="${IMAGE_TAG:-volvoxgrid-build:latest}"

echo "Building Docker image: ${IMAGE_TAG}"
docker build -t "${IMAGE_TAG}" -f "${REPO_ROOT}/Dockerfile" "${REPO_ROOT}"

RUN_ARGS=(
  --rm
  -e "BUILD_MODE=${MODE}"
  -e "REPO_ROOT=${CONTAINER_REPO_ROOT}"
  -v "${WORKSPACE_ROOT}:/workspace"
  -w "${CONTAINER_REPO_ROOT}"
)

for var in DIST_ROOT; do
  if [[ -n "${!var:-}" ]]; then
    RUN_ARGS+=(-e "${var}=${!var}")
  fi
done

echo "Running container build (mode=${MODE})..."
docker run "${RUN_ARGS[@]}" "${IMAGE_TAG}"

echo
echo "Done."
if [[ "${MODE}" == "all" ]]; then
  echo "Artifacts: ${REPO_ROOT}/dist/docker/{gpu,cpu}"
else
  echo "Artifacts: ${REPO_ROOT}/dist/docker/${MODE}"
fi

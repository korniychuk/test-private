#!/usr/bin/env bash

set -euxo pipefail

declare -r SCRIPT_PATH="$( cd "$(dirname "$0")" ; pwd -P )"

function calculateContainerTag() {
  local -r deployEndpoint="${1}"

  if [[ "${deployEndpoint}" == "prod" ]]; then
      echo 'latest'
  elif [[ "${deployEndpoint}" == "dev" ]]; then
      echo 'develop'
  else
      echo "${deployEndpoint}"
  fi
}

function deploy() {
  local -r endpoint="${1}"
  local -r controlPhrase='Deploy:OK'

  echo -e '\n----- BEGIN Triggering docker pull -----\n'

  local res=$( \
      curl \
          -X POST "${DEPLOY_TRIGGER_URL}/${endpoint}" \
          -u "${DEPLOY_BASEAUTH_USER}:${DEPLOY_BASEAUTH_PASSWORD}" \
          --http1.1 \
          --silent \
          -i
  )

  echo "${res}"

  echo -e '\n----- END Triggering docker pull -----\n'

  if [[ -z $(echo "${res}" | grep "${controlPhrase}") ]]; then
      echo 'Pulling finished with an error' >&2
      exit 1
  else
      echo 'Pulling completed successful'
  fi
}

function main() {
  local -r deployEndpoint="${1}"
  local -r action="${2}"

  local -r imageName="${DOCKER_PRIVATE_REGISTRY}/${DOCKER_IMAGE}"
  local -r imageTag=$(calculateContainerTag "${deployEndpoint}")
  local -r imageFullId="${imageName}:${imageTag}"

  case "${action}" in
    #
    # Build docker image
    #
    docker-build)
      docker build -t "${imageFullId}" $(readlink -f "${SCRIPT_PATH}/../..")
      ;;

    #
    # Pushing docker image to the registry
    #
    docker-push)
      echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin "$DOCKER_PRIVATE_REGISTRY"
      docker push "${imageFullId}"
      ;;

    #
    # Trigger pulling docker image on the server
    #
    deploy)
      deploy "${deployEndpoint}"
      ;;

    *)
      echo 'deploy.sh Error: Unknown $action' >&2
      exit 1
      ;;
  esac
}

main "${1}" "${2}"

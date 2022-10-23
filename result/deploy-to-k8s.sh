#!/bin/bash

set -euo pipefail

declare -r R_DEFAULT_JOB_ROLLOUT_MODE="fire_and_forget_job"
declare -r DEFAULT_SERVICE_ROLLOUT_MODE="watch_service"
declare -r WATCH_JOB_ROLLOUT_MODE="watch_job"
declare -r DEFAULT_NAMESPACE="flink-assignment"
declare -r f_DEFAULT_DEPLOYMENT_WATCH_TIMEOUT_IN_SEC=660

function log() {
  echo -e " $(date +%Y/%m/%dT%H:%M:%S)\t${1}"
}

function log_and_run() {
  log "$*"
  "$@"
}

function watch_deployment_rollout() {
  local deployment_manifest="${1}"
  local namespace="${2}"
  local timeout_s="${3}"
  log "Watching rollout of ${deployment_manifest} (timeout: $timeout_s seconds)"
  if ! timeout ${timeout_s} kubectl rollout status -f ${deployment_manifest} -n ${namespace} --watch ; then
    log "Deployment watch rollout either failed or timed out after $timeout_s seconds. If it timed out then the deployment succeeded or failed but couldnt find out"
  else
    # verify type:Available status:True, meaning deployment has succeeded!
    local stat="$(kubectl get -f "${deployment_manifest}" -o jsonpath='{.status.conditions[0].type}={.status.conditions[0].status}|{.status.conditions[0].lastUpdateTime} {.status.conditions[0].reason} {.status.conditions[0].message}')"
    local type_status="${stat%%|*}" # delete longest |* substring from back of status, 'Available=True'
    local text="${stat#*|}" # delete longest *| substring from front of status, '<time> MinReplicasAvailable some message'
    if [[ ${type_status} == 'Available=True' ]] ; then
      log "Deployment succeeded with status ${type_status} - $text"
      return 0
    else
      log "Deployment is still pending and probably not healthy... ${type_status} - $text. You should perform a rollback"
    fi
  fi
  exit 1
}

function kubectl_create_or_replace() {
  if [[ -f "${1}" ]] ; then
    if kubectl get -f "$1" &>/dev/null ; then
      local verb="replace"
    else
      local verb="create"
    fi
    log "Deploying ${1}"
    kubectl "$verb" -f -
  else
    log "${1} was not found. Skipping ..."
  fi
}

function deploy_resource_with() {
  local image_tag=${1}
  local tx_id=${2}
  local resource_path=${3}
  sed "s|_DOCKER_IMAGE_TAG_|${image_tag}|g; s|_TX_|${tx_id}|g" ${resource_path} | \
  kubectl_create_or_replace "${resource_path}"
}

function  main() {
  local component=${1}
  local env=${2:-dev}
  local image_tag=${3:-""}
  local namespace=${4:-${DEFAULT_NAMESPACE}}
  local job_rollout_mode=${5:-${DEFAULT_JOB_ROLLOUT_MODE}}
  local service_rollout_mode=${6:-${DEFAULT_SERVICE_ROLLOUT_MODE}}
  local tx_id=$(date +%Y%m%d%H%M%S)
  local manifests_path="manifests/PRODUCTION/${env}/${component}"
  log "Deploying ${component} to $(kubectl config current-context) using configs in ${manifests_path}"
  for resource in `ls ${manifests_path}`;do
    deploy_resource_with "${image_tag}" "${tx_id}" "${manifests_path}/${resource}"
  done
  if [[ "${job_rollout_mode}" == "${WATCH_JOB_ROLLOUT_MODE}" ]]; then
    local pod=$(kubectl -n ${namespace} get pods | grep ${tx_id} | awk '{ print $1}' | tail -1)
    log_and_run sleep 160s
    log_and_run kubectl -n ${namespace} logs ${pod} -f
    log_and_run sleep 10s
    local status=$(kubectl -n ${namespace} get pod ${pod} | awk '{ print $3}' | tail -1)
    if [[ ${status} != "Completed" ]]; then
      log "Job that run on ${pod} failed"
      exit 1
    else
      log "Job completed successfully"
    fi
  fi
  if [[ "${service_rollout_mode}" == "${DEFAULT_SERVICE_ROLLOUT_MODE}" ]]; then
    watch_deployment_rollout "${manifests_path}/jobmanager-deployment.yaml" ${namespace} ${DEFAULT_DEPLOYMENT_WATCH_TIMEOUT_IN_SEC}
    watch_deployment_rollout "${manifests_path}/taskmanager-deployment.yaml" ${namespace} ${DEFAULT_DEPLOYMENT_WATCH_TIMEOUT_IN_SEC}
    log_and_run sleep 60s
  fi
}

main "$@"

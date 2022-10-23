#!/bin/bash

set -euo pipefail

declare -r FLINK_HOME=${FLINK_HOME:-"/usr/local/flink"}
declare -r FLINK_CONF_DIR=${FLINK_CONF_DIR:-"/usr/local/flink/conf"}
declare -r TRACK=${TRACK:-"dev"}
declare -r FLINK_LIB_DIR=${FLINK_HOME}/lib
declare -r FLINK_OPT_DIR=${FLINK_HOME}/opt
declare -r FLINK_PLUGINS_DIR=${FLINK_HOME}/plugins
# If unspecified, the hostname of the container is taken as the JobManager address
declare -r JOB_MANAGER_RPC_ADDRESS=${JOB_MANAGER_RPC_ADDRESS:-$(hostname -f)}
declare -r CONF_FILE="${FLINK_CONF_DIR}/flink-conf.yaml"
declare -r QUERYABLE_STATE_RUNTIME_JAR="flink-queryable-state-runtime_*.jar"
declare -r PROMETHEUS_METRIC_JAR="flink-metrics-prometheus-*.jar"

function log() {
  echo -e " $(date +%Y/%m/%dT%H:%M:%S)\t${1}"
}

function log_and_run() {
  log "$*"
  "$@"
}

function set_flink_confs() {
  log_and_run export HADOOP_CLASSPATH=$(hadoop classpath)
  log_and_run cp ${FLINK_CONF_DIR}/${TRACK}/flink-conf.yaml ${CONF_FILE}
  log_and_run cp ${FLINK_OPT_DIR}/${QUERYABLE_STATE_RUNTIME_JAR} ${FLINK_LIB_DIR}/
  log_and_run cp ${FLINK_PLUGINS_DIR}/metrics-prometheus/${PROMETHEUS_METRIC_JAR} ${FLINK_LIB_DIR}/
}

function compute_memory_settings() {
  local total_memory=$(echo ${TOTAL_MEMORY_MiB} | tr 'm' '\n' | grep -v i)
  TASK_MANAGER_MEMORY=$(python -c "print(int((1+$ON_HEAP_FACTOR)*$total_memory))")
  FLINK_MEMORY=$(python -c "print(int((1+$ON_HEAP_FACTOR)*$total_memory - $OFF_HEAP_JVM_METASPACE - $OFF_HEAP_JVM_OVERHEAD))")
  export TASK_MANAGER_MEMORY
  export FLINK_MEMORY
  log "Computed memory settings: flink memory=${FLINK_MEMORY} ,total memory=${total_memory} ,task manager memory=${TASK_MANAGER_MEMORY}"
}

function run_flink_process() {
  local process=${1}
  shift 1
  log "Running ${process} ..."
  log "envsubst - ${FLINK_HOME}/conf/flink-${process}-conf.yaml -- ${CONF_FILE}"
  envsubst < ${FLINK_HOME}/conf/flink-${process}-conf.yaml >> ${CONF_FILE}
  log "Env variables:"
  log_and_run export
  log "Configuration files:"
  log_and_run ls ${FLINK_HOME}/conf/
  log "Flink config file: "
  log_and_run grep '^[^\n#]' "${CONF_FILE}"
  log "exec ${FLINK_HOME}/bin/${process}.sh start-foreground $@"
  exec ${FLINK_HOME}/bin/${process}.sh start-foreground "$@"
}

function main() {
  while [ $# -gt 0 ]; do
    case $1 in
    jobmanager)
      set_flink_confs
      run_flink_process "$@"
      break
      ;;
    taskmanager)
      set_flink_confs
      compute_memory_settings
      run_flink_process "$@"
      break
      ;;
    python|bash)
      /bin/$@
      break
      ;;
    help)
      log "Usage: $(basename "$0") (jobmanager|taskmanager|help|python|bash)"
      break
      ;;
    *)
      log "ERROR: Unknown parameter ${1}"
      exit 1
      ;;
    esac
    shift
  done
}

main "$@"

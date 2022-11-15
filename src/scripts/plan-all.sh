#!/bin/bash
# Check CLI config file
if [[ -n "${TF_PARAM_CLI_CONFIG_FILE}" ]]; then
  if [[ -f "${TF_PARAM_CLI_CONFIG_FILE}" ]]; then
    export TF_CLI_CONFIG_FILE=${TF_PARAM_CLI_CONFIG_FILE}
  else
    echo "Terraform cli config does not exist: ${TF_PARAM_CLI_CONFIG_FILE}"
    exit 1
  fi
fi
# 'path' is a required parameter, save it as module_path
readonly module_path="${TF_PARAM_PATH}"
export path=$module_path
if [[ ! -d "$module_path" ]]; then
  echo "Path does not exist: $module_path"
  exit 1
fi
# the following is needed to process backend configs
if [[ -n "${TF_PARAM_BACKEND_CONFIG_FILE}" ]]; then
  for file in $(echo "${TF_PARAM_BACKEND_CONFIG_FILE}" | tr ',' '\n'); do
    if [[ -f "$module_path/$file" ]]; then
      INIT_ARGS="$INIT_ARGS -backend-config=$file"
    else
      echo "Backend config '$file' wasn't found" >&2
      exit 1
    fi
  done
fi
if [[ -n "${TF_PARAM_BACKEND_CONFIG}" ]]; then
  for config in $(echo "${TF_PARAM_BACKEND_CONFIG}" | tr ',' '\n'); do
    INIT_ARGS="$INIT_ARGS -backend-config=$(eval echo "$config")"
  done
fi
export INIT_ARGS

workspace_parameter="$(eval echo "${TF_PARAM_WORKSPACE}")"
readonly workspace="${TF_WORKSPACE:-$workspace_parameter}"
export workspace
unset TF_WORKSPACE

# Test for saving state locally vs a remote state backend storage
if [[ -n "$workspace_parameter" ]]; then
  echo "[INFO] Provisioning local workspace: $workspace"
  terraform -chdir="$module_path" workspace select "$workspace" || terraform -chdir="$module_path" workspace new "$workspace"
else
  echo "[INFO] Remote State Backend Enabled"
fi

if [[ -n "${TF_PARAM_VAR}" ]]; then
  for var in $(echo "${TF_PARAM_VAR}" | tr ',' '\n'); do
    PLAN_ARGS="$PLAN_ARGS -var $(eval echo "$var")"
  done
fi
if [[ -n "${TF_PARAM_VAR_FILE}" ]]; then
  for file in $(eval echo "${TF_PARAM_VAR_FILE}" | tr ',' '\n'); do
    if [[ -f "$module_path/$file" ]]; then
      PLAN_ARGS="$PLAN_ARGS -var-file=$file"
    else
      echo "var file '$file' wasn't found" >&2
      exit 1
    fi
  done
fi

if [[ -n "${TF_PARAM_LOCK_TIMEOUT}" ]]; then
  PLAN_ARGS="$PLAN_ARGS -lock-timeout=${TF_PARAM_LOCK_TIMEOUT}"
fi
export PLAN_ARGS

if [[ -n "${TG_PARAM_STRICT_INCLUDE}" ]]; then
  TG_ARGS="$TG_ARGS --terragrunt-strict-include"
fi
if [[ -n "${TG_PARAM_EXCLUDE_DIR}" ]]; then
  for edir in $(echo "${TG_PARAM_EXCLUDE_DIR}" | tr ',' '\n'); do
     TG_ARGS="$TG_ARGS --terragrunt-exclude-dir $edir"
  done
fi
if [[ -n "${TG_PARAM_INCLUDE_DIR}" ]]; then
  for idir in $(echo "${TG_PARAM_INCLUDE_DIR}" | tr ',' '\n'); do
     TG_ARGS="$TG_ARGS --terragrunt-include-dir $idir"
  done
fi
export TG_ARGS


echo "--terragrunt-working-dir $module_path $TG_ARGS -input=false -out=${TF_PARAM_OUT} $PLAN_ARGS"
# shellcheck disable=SC2086
terragrunt run-all plan --terragrunt-working-dir "$module_path" $TG_ARGS -input=false -out=${TF_PARAM_OUT} $PLAN_ARGS

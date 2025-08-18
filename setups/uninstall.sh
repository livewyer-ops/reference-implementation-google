#!/bin/bash
set -e -o pipefail

REPO_ROOT=$(git rev-parse --show-toplevel)
SETUP_DIR="${REPO_ROOT}/setups"
TF_DIR="${REPO_ROOT}/terraform"
source ${REPO_ROOT}/setups/utils.sh

cd ${SETUP_DIR}

echo -e "${PURPLE}\nTargets:${NC}"
echo "Kubernetes cluster: $(kubectl config current-context)"
echo "GCP account (if set): $(gcloud info --format json | jq -rc '.config.account')"
echo "GCP project: $(gcloud info --format json | jq -rc '.config.project')"

echo -e "${RED}\nAre you sure you want to continue?${NC}"
read -p '(yes/no): ' response
if [[ ! "$response" =~ ^[Yy][Ee][Ss]$ ]]; then
  echo 'exiting.'
  exit 0
fi

cd "${TF_DIR}"
terraform destroy

cd "${SETUP_DIR}/argocd/"
./uninstall.sh
cd -

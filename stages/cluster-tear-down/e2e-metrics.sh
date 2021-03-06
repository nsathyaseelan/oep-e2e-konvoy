#!/bin/bash

pod() {
  echo "************* Setting up the cluster for e2e metrics *************"
  sshpass -p $pass ssh -o StrictHostKeyChecking=no $user@$ip -p $port 'cd oep-e2e-konvoy && bash stages/cluster-tear-down/e2e-metrics.sh node '"'$CI_PIPELINE_ID'"' '"'$CI_JOB_ID'"''
}

node() {
  
  bash utils/e2e-cr jobname:e2e-metrics jobphase:Waiting
  bash utils/e2e-cr jobname:e2e-metrics jobphase:Running 
  bash utils/e2e-cr jobname:cluster-cleanup jobphase:Waiting

  # Set environment variables
  COVERAGE_NAMESPACE="e2e-metrics"
  E2E_METRICS_PIPELINE_ID=$(echo $1)
  E2E_METRICS_COVERAGE_NAME="oep-e2e-konvoy-coverage"
  E2E_METRICS_RUN_ID=$(echo $2)

  # Setting var for error - No resources found.
  no_resources_found=No\ resources\ found

  # Copy master-plan
  cp oep-e2e/.master-plan.yml .master-plan.yml

  # Create namespace for e2e-metric components
  kubectl create ns $COVERAGE_NAMESPACE

  # Create configmap from master test plan file
  kubectl create configmap metrics-config-test -n $COVERAGE_NAMESPACE --from-file=.master-plan.yml --from-file=.gitlab-ci.yml

  # Create kubernetes resources
  kubectl apply -f e2e-metrics/deploy/rbac.yaml
  kubectl apply -f e2e-metrics/deploy/crd.yaml
  kubectl create configmap metac-config-test -n $COVERAGE_NAMESPACE --from-file="e2e-metrics/deploy/metac-config.yaml"
  kubectl apply -f e2e-metrics/deploy/operator.yaml
  kubectl set env sts/e2e-metrics E2E_METRICS_PIPELINE_ID=$E2E_METRICS_PIPELINE_ID -n $COVERAGE_NAMESPACE
  kubectl set env sts/e2e-metrics E2E_METRICS_COVERAGE_NAME=$E2E_METRICS_COVERAGE_NAME -n $COVERAGE_NAMESPACE
  kubectl set env sts/e2e-metrics E2E_METRICS_RUN_ID=$E2E_METRICS_RUN_ID -n $COVERAGE_NAMESPACE

  pcover_cr=$(kubectl get pcover -n $COVERAGE_NAMESPACE 2>&1)  # 2>&1 redirects stderr to stdout

  # The below line turns off case sensitive comparison of strings
  shopt -s nocasematch

  # Check if pcover CR has been created or not
  while [[ $pcover_cr == *error* ]]
  do
    pcover_cr=$(kubectl get pcover -n $COVERAGE_NAMESPACE 2>&1)
    echo "Waiting for the CR 'pcover' to be created"
    sleep 10
  done

  # Check if the e2e-metrics pod is in Running state or not
  e2e_metrics_pod_state=$(kubectl get po -n $COVERAGE_NAMESPACE --no-headers  | awk '{print $3}')
  while [[ $e2e_metrics_pod_state != "Running" ]]
  do
    e2e_metrics_pod_state=$(kubectl get po -n $COVERAGE_NAMESPACE --no-headers  | awk '{print $3}')
    pod_name=$(kubectl get po -n $COVERAGE_NAMESPACE --no-headers  | awk '{print $1}')
    echo "Waiting for the pod $pod_name to be Running"
    sleep 10
  done

  # Check e2e-coverage-cr has been created or not
  e2e_coverage_cr=$(kubectl get pcover -n $COVERAGE_NAMESPACE --no-headers | awk '{print $1}' 2>&1)
  while [[ $e2e_coverage_cr == *$no_resources_found* ]]
  do
    e2e_coverage_cr=$(kubectl get pcover -n $COVERAGE_NAMESPACE --no-headers | awk '{print $1}' 2>&1)
    echo "Waiting for the e2e-coverage-cr to be created"
    sleep 5
  done

  echo "e2e-coverage CR: $e2e_coverage_cr"

  # Fetch coverage percentage from custom resource
  kubectl get pcover $e2e_coverage_cr -n $COVERAGE_NAMESPACE -oyaml
  kubectl get pcover -n $COVERAGE_NAMESPACE -o=jsonpath='{.items[0].result.coverage}{"\n"}'

  bash utils/e2e-cr jobname:e2e-metrics jobphase:Completed
}

if [ "$1" == "node" ];then
  node $2 $3
else
  pod
fi
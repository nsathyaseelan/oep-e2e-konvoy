#!/bin/bash

# Specify test name
test_name=od-elasticsearch-logging-health-check
echo "Test name: $test_name"

sed -e 's/generateName: app-check/generateName: '"$test_name"'/g' \
-e 's/app: app-litmus/app: od-elasticsearch-logging-health-check-litmus/g' \
-e 's/value: test-name/value: '"$test_name"'/g' \
-e 's/value: default /value: default/g' \
-e 's/value: pod-name/value: od-elasticsearch-logging/g' oep/litmus/director/common-checks/run_litmus_test.yml \
> oep/litmus/director/common-checks/es_run_litmus_test.yml

cat oep/litmus/director/common-checks/es_run_litmus_test.yml

# Run common health check litmus job
kubectl create -f oep/litmus/director/common-checks/es_run_litmus_test.yml

# Check common health check job status
litmus_pod=$(kubectl get po -n litmus | grep $test_name  | awk {'print $1'} | tail -n 1)
echo "Litmus pod name: $litmus_pod"

job_status=$(kubectl get po  $litmus_pod -n litmus | awk {'print $3'} | tail -n 1)

# Check completed status for job
while [[ "$job_status" != "Completed" ]]
do 
  job_status=$(kubectl get po  $litmus_pod -n litmus | awk {'print $3'} | tail -n 1)
  echo "Waiting for job status to be Completed"
  sleep 6
done

# Print common health check job logs
echo "Job logs:"
kubectl logs -f $litmus_pod -n litmus

# Check common health check job result
testResult=$(kubectl get litmusresult $test_name --no-headers -o custom-columns=:spec.testStatus.result)
echo "Test result: $testResult" 

# Flush test result in result.txt
echo "$test_name: $testResult" >> result.txt;
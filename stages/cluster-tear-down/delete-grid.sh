#!/bin/bash

pod() {
  ## Cleaning up selenium-grid
  echo -e "\n*************Cleaning up Selenium Grid****************\n"
  sshpass -p $pass ssh -o StrictHostKeyChecking=no $user@$ip -p $port 'cd oep-e2e-konvoy && bash stages/cluster-tear-down/delete-grid.sh node '"'$CI_PROJECT_NAME'"' '"'$CI_PIPELINE_ID'"''
}

node() {

  CI_PROJECT_NAME=$(echo $1)
  CI_PIPELINE_ID=$(echo $2)
  GUID=grid-${CI_PROJECT_NAME}-${CI_PIPELINE_ID}

  {
    aws cloudformation delete-stack --stack-name ${GUID}
  } || {
    echo 'Selenium CloudFormation stack was absent'
  }
}

if [ "$1" == "node" ];then
  node $2 $3
else
  pod
fi
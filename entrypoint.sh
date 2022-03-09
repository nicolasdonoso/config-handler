#!/bin/sh

git clone --single-branch --branch master https://$GH_TOKEN@github.com/SwishAnalytics/k8s-templates.git

# ls -alh k8s-templates/

echo $K8S_KUBECONFIG | base64 -d > ./kube_config
kubectl config use-context $K8S_CLUSTER
export RUN_ID=$GITHUB_RUN_ID ## Make this variable depending CI/CD provider
if [[ -z $ECR_REPO ]]
    then echo "ECR repo name defined by repo name"
    export REPO_NAME=$(echo $GITHUB_REPOSITORY|cut -d '/' -f2)
else
    echo "ECR repo name defined by env var ECR_REPO"
    export REPO_NAME=$ECR_REPO
fi

echo "parsing configs"

for i in $(cat deploy/config.json|jq -r '.|keys[] as $k| "\($k),\(.[$k])"' )
  do export $(echo $i|cut -d',' -f1)=$(echo $i|cut -d',' -f2)
done

if [[ $REPO_NAME == "core-push" ]]
  then
  export 
fi

## Check env var values
# env

if [[ $image == "Dockerfile" ]]
  then echo "image with no prefix"
  export img_prefix=""
  echo $image
  echo $img_prefix
else
  echo "setting image prefix"
  export img_prefix=$(echo $image| cut -d "." -f 2)-
  echo $image
  echo $img_prefix
fi
if [[ -f deploy/secrets.yml ]]
  then echo "adding secrets"
  envsubst < deploy/secrets.yml > secrets.yml
  export creds=$(awk -v ORS="\n        " 1 secrets.yml)
fi
if [[ $local_redis == 'true' ]]
  then echo "adding local redis"
  export REDIS_HOST="localhost"
  envsubst < k8s-templates/manifests/sockets/redis.yml > redis.yml
  export redis=$(awk -v ORS="\n      " 1 redis.yml)
fi
if [[ $command == "dummy" ]]
  then echo "exporting command"
    export command="command: ['/bin/bash', '-c', 'tail -f /dev/null']"
    # echo $command
elif [[ -n $command ]]
  then echo "exporting command"
    export command="command: ['/bin/bash', '-c', '${command}']"
    echo $command
fi
if [[ $privileged == "true" ]]
  then echo "creating service account"
  export sa="serviceAccountName: ${PROJECT}"
  export securityContextUser="privileged: true"
  echo $sa
  echo $securityContextUser
  envsubst < manifests/global/privileged-sa.yml > service-account.yml
  kubectl apply -f service-account.yml -n $CI_ENVIRONMENT_NAME
else
  export securityContextUser="runAsUser: 999"
fi
if [[ $cors == "true" ]]
  then echo "adding cors to ingress"
  export cors="nginx.ingress.kubernetes.io/enable-cors: '${cors}'"
else
  export cors=""
fi
if [[ $public_accessible == "true" ]]
then
  echo "public access service"
  if [[ $CI_ENVIRONMENT_NAME == *"dev"* ]]
    then export ips=$(awk -v ORS="\n\  " 1 manifests/global/private.txt)
  else
    export ips=$(awk -v ORS="\n\  " 1 manifests/global/public.txt) 
  fi
else
  echo "NO public access service"
  export ips=$(awk -v ORS="\n\  " 1 manifests/global/private.txt)
fi

if [[ $SERVICE == 'true' ]];
  then echo "deploying service resources"
  if [[ $ROUTE ]]
    then echo "adding custom path / route"
    export SERVICE_NAME=$ROUTE
  fi
  if [[ -f deploy/deployment.yml ]]
    then echo "local files"
    envsubst < deploy/deployment.yml > deployment.yml
    envsubst < deploy/ingress.yml > ingress.yml
    envsubst < deploy/service.yml > service.yml
  else
    echo "template files"
    envsubst < k8s-templates/manifests/global/deployment.yml > deployment.yml
    envsubst < k8s-templates/manifests/services/ingress.yml > ingress.yml
    envsubst < k8s-templates/manifests/global/service.yml > service.yml
  fi
  # kubectl apply -f ingress.yml -n $CI_JOB_STAGE
  # kubectl apply -f service.yml -n $CI_JOB_STAGE
elif [[ ! -z $INGRESS_CLASS ]];
  then echo "deploying sockets resources"
  if [[ -f deploy/deployment.yml ]]
    then echo "local files"
    envsubst < deploy/deployment.yml > deployment.yml
    envsubst < deploy/ingress.yml > ingress.yml
    envsubst < deploy/service.yml > service.yml
  else
    echo "template files"
    envsubst < k8s-templates/manifests/global/deployment.yml > deployment.yml
    envsubst < k8s-templates/manifests/sockets/ingress.yml > ingress.yml
    envsubst < k8s-templates/manifests/global/service.yml > service.yml
  fi
  # kubectl apply -f ingress.yml -n $CI_JOB_STAGE
  # kubectl apply -f service.yml -n $CI_JOB_STAGE
else
  echo "deploying other"
  envsubst < k8s-templates/manifests/global/deployment.yml > deployment.yml
  if [[ -f deploy/deployment.yml ]]
    then echo "local files"
    envsubst < deploy/deployment.yml > deployment.yml
  fi
fi

# kubectl apply -f deployment.yml -n $CI_JOB_STAGE

cat deployment.yml
cat ingress.yml
cat service.yml
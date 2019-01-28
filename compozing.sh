#!/bin/bash

# Check variables
if [ -z $DOCKER_REGISTRY ] || \
   [ -z $DOCKER_USER ] || \
   [ -z $DOCKER_PSWD ] || \
   [ -z $REPO ] || \
   [ -z $BRANCH ] || \
   [ -z $COMMIT ] || \
   [ -z $BUILD ]; then
     echo "ensure that all variables sets";
     exit 2
fi;

## PROCEDURES ##
values(){
  export DOCKER_REPO=$(echo "$( echo ${REPO} )/$( echo ${BRANCH} | tr -cd '[:alnum:]' )" | tr '[:upper:]' '[:lower:]' );
  export TAG="${BUILD}_$(echo ${COMMIT} | cut -c 1-7)";
  export IMAGE=$( echo "${DOCKER_REGISTRY}/${DOCKER_REPO}:${TAG}" )
  echo "IMAGE: $IMAGE";
};

login(){
  docker login ${DOCKER_REGISTRY} \
            -u ${DOCKER_USER} \
            -p ${DOCKER_PSWD} || \
            (echo "failed login: $?" && exit 11);
};

check(){
  if [ "$1" == "print" ]; then
    mode='';
  else
    mode="--services"; #print service | '--quiet' only validate config without printing anything
  fi;
  docker-compose config $mode || \
        (echo "failed config" && OK=false && exit 21);
};

build(){
  docker-compose build  || \
        (echo "failed build" && check print && exit 22);
};

up(){
  docker-compose up -d || \
        (echo "failed up" && check print && exit 23);
};

hc(){
  ScriptUrl=https://raw.githubusercontent.com/lifeci/healthchecks/1.1/compose-all.sh
  #export  DelayInput=8;
  curl -Ssk $ScriptUrl | bash -f -- || \
        (echo "failed hc" && OK=false && exit 24);
};

push(){
  echo "pusing with TAG: ${TAG}";
  docker-compose push || \
        (echo "failed push ${TAG}" && exit 31);
};

push_latest(){
  export TAG=latest
  echo "pushing with TAG: ${TAG}";
  ( docker-compose build > /dev/null ) && docker-compose push || \
        (echo "failed push ${TAG}" && exit 32);
};

artifact(){
  if [ ! -z $IMAGE ]; then
    echo "$IMAGE" | tee /tmp/${BUILD}.IMAGE;
    ls -la /tmp/${BUILD}.IMAGE;
  else
    echo "IMAGE is empty" && exit 32;
  fi;
};

cleanup(){
  docker-compose down;
  docker logout ${DOCKER_REGISTRY};
};


## EXECUTION LOOP ##

for action in values login check build up hc push push_latest artifact; do
  printf "\n\n\t### START: $action ###\n"
  $action
  exitCode=$?;
  if [ $exitCode != 0 ]; then
    printf "\t FAILED: $action with exitCode: $exitCode\n";
    break $exitCode;
  else
    printf "\t### END: $action ###\n"
  fi;
done;

printf "\n\t### CLEANUP: always ###\n"
cleanup;  #always
exit $exitCode

#!/bin/bash
############################################
#####   Ericom Shield Stop             #####
#######################################BH###

ES_PATH=/usr/local/ericomshield
STACK_NAME=shield

echo "***********       Stopping EricomShield "
echo "***********       "
if [ -z $(docker info | grep -i 'swarm: active') ]; then
    echo "Docker swarm is not active, '$STACK_NAME' stack is not running."
    exit 0
fi
#   docker swarm leave -f
docker stack rm $STACK_NAME
limit=10
echo "Waiting for $STACK_NAME to stop..."
until [ -z "$(docker service ls --filter label=com.docker.stack.namespace=$STACK_NAME -q)" ] || [ "$limit" -lt 1 ]; do
    echo $limit
    sleep 1
    limit=$((limit - 1))
done
echo "done"

#!/bin/bash
# saner programming env: these switches turn some bugs into errors
set -o errexit -o pipefail -o noclobber -o nounset

! getopt --test > /dev/null 
if [[ ${PIPESTATUS[0]} -ne 4 ]]; then
    echo 'I’m sorry, `getopt --test` failed in this environment.'
    exit 1
fi

usage="$(basename "$0") [ -h | --help ] [ -b | --build ] [ -p | --push ] -- program to build and push docker container images"
echo "$usage"

help="
where:
	-h, --help:  help
	-b, --build: build container
	-p, --push:  push a new version (patch, minor, or major)"


OPTIONS=hbp:v
LONGOPTS=help,build,push:,verbose

# -use ! and PIPESTATUS to get exit code with errexit set
# -temporarily store output to be able to check for errors
# -activate quoting/enhanced mode (e.g. by writing out “--options”)
# -pass arguments only via   -- "$@"   to separate them correctly
! PARSED=$(getopt --options=$OPTIONS --longoptions=$LONGOPTS --name "$0" -- "$@")
if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
    # e.g. return value is 1
    #  then getopt has complained about wrong arguments to stdout
    exit 2
fi
# read getopt’s output this way to handle the quoting right:
eval set -- "$PARSED"

h=n b=n p=n v=n pushMode=-
# now enjoy the options in order and nicely split until we see --
while true; do
    case "$1" in
        -h|--help)
            h=y
            shift
            ;;
        -b|--build)
            b=y
            shift
            ;;
        -p|--push)
            pushMode="$2"
            shift 2
            ;;
        -v|--verbose)
            v=y
            shift
            ;;
        --)
            shift
            break
            ;;
        *)
            echo "Programming error"
            exit 3
            ;;
    esac
done

# handle non-option arguments
# if [[ $# -ne 1 ]]; then
#    echo "$0: A push mode is required"
#    exit 4
# fi

source ./deploy.env
IMG_NAME=$DOCKER_REPO/$APP_NAME
echo "verbose: $v, build: $b, push: $pushMode, help: $h"

if [ "$h" = "y" ]; then
    printf "$help\n"
fi

if [ "$b" = "y" ]; then
    printf "Building docker image: \n"
	GIT_VER=$(git rev-parse @)
	PREV_GIT_VER=$(git rev-parse @~)
	PREV_ID=$(docker images -f reference=$IMG_NAME:latest --format "{{.ID}}")
	PREV_GIT_TAG=$(docker images -f reference=$IMG_NAME:$PREV_GIT_VER --format "{{.Tag}}")
	printf "Image: $IMG_NAME:$GIT_VER\n"
	docker build -t $IMG_NAME:latest .
	docker tag $IMG_NAME:latest $IMG_NAME:$GIT_VER
	CUR_ID=$(docker images -f reference=$IMG_NAME:latest --format "{{.ID}}")
	if [ "$PREV_ID" != "$CUR_ID" ]; then
		docker image rm $PREV_ID
	elif [ ! -z "$PREV_GIT_TAG" ]; then
		docker image rm "$IMG_NAME:$PREV_GIT_TAG"
	fi
fi

if [ "$pushMode" != "-" ]; then
    case "$pushMode" in
        patch)
             PREV_SEM_VER="v$(jq -rM '.version' package.json)"
			 NEW_SEM_VER=$(npm version patch)
			 printf "Previous sem version: $PREV_SEM_VER\n"
			 printf "New sem version: $NEW_SEM_VER\n"
			 NEW_GIT_VER=$(git rev-parse @)
			 PREV_GIT_VER=$(git rev-parse @~)
			 docker tag $IMG_NAME:latest $IMG_NAME:$NEW_GIT_VER
			 docker image rm $IMG_NAME:$PREV_GIT_VER
			 docker push $IMG_NAME:$NEW_GIT_VER
			 docker push $IMG_NAME:latest
			 docker tag $IMG_NAME:$NEW_GIT_VER $IMG_NAME:$NEW_SEM_VER
			 docker push $IMG_NAME:$NEW_SEM_VER
			 docker image rm $IMG_NAME:$NEW_SEM_VER
            ;;
        minor)
             PREV_SEM_VER="v$(jq -rM '.version' package.json)"
			 NEW_SEM_VER=$(npm version minor)
			 printf "Previous sem version: $PREV_SEM_VER\n"
			 printf "New sem version: $NEW_SEM_VER\n"
			 NEW_GIT_VER=$(git rev-parse @)
			 PREV_GIT_VER=$(git rev-parse @~)
			 docker tag $IMG_NAME:latest $IMG_NAME:$NEW_GIT_VER
			 docker image rm $IMG_NAME:$PREV_GIT_VER
			 docker push $IMG_NAME:$NEW_GIT_VER
			 docker push $IMG_NAME:latest
			 docker tag $IMG_NAME:$NEW_GIT_VER $IMG_NAME:$NEW_SEM_VER
			 docker push $IMG_NAME:$NEW_SEM_VER
			 docker image rm $IMG_NAME:$NEW_SEM_VER
            ;;
        major)
             PREV_SEM_VER="v$(jq -rM '.version' package.json)"
			 NEW_SEM_VER=$(npm version major)
			 printf "Previous sem version: $PREV_SEM_VER\n"
			 printf "New sem version: $NEW_SEM_VER\n"
			 NEW_GIT_VER=$(git rev-parse @)
			 PREV_GIT_VER=$(git rev-parse @~)
			 docker tag $IMG_NAME:latest $IMG_NAME:$NEW_GIT_VER
			 docker image rm $IMG_NAME:$PREV_GIT_VER
			 docker push $IMG_NAME:$NEW_GIT_VER
			 docker push $IMG_NAME:latest
			 docker tag $IMG_NAME:$NEW_GIT_VER $IMG_NAME:$NEW_SEM_VER
			 docker push $IMG_NAME:$NEW_SEM_VER
			 docker image rm $IMG_NAME:$NEW_SEM_VER
            echo major
            ;;
        *)
            echo push must be one of patch, minor, or major
    esac
fi
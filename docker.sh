#!/bin/bash
# saner programming env: these switches turn some bugs into errors
set -o errexit -o pipefail -o noclobber -o nounset

! getopt --test > /dev/null 
if [[ ${PIPESTATUS[0]} -ne 4 ]]; then
    echo 'I’m sorry, `getopt --test` failed in this environment.'
    exit 1
fi

usage="$(basename "$0") [ -h | --help ] [-i | --info] [ -b | --build ] [ -p | --push ] -- program to build and push docker container images"
echo "$usage"

help="
where:
	-h, --help  : help
	-i, --info  : get the current projects repo/name
	-b, --build : build container
	-p, --push  : push a new version (patch, minor, or major)"


OPTIONS=hibp:
LONGOPTS=help,info,build,push:,

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

h=n b=n i=n pushMode=-
# now enjoy the options in order and nicely split until we see --
while true; do
    case "$1" in
        -h|--help)
            h=y
            shift
            ;;
		-i|--info)
			i=y
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

source ./deploy.env
IMG_NAME=$DOCKER_REPO/$APP_NAME

if [ "$h" = "y" ]; then
    printf "$help\n"
fi

if [ "$i" = "y" ]; then
	printf "Repo/App: $IMG_NAME\n"
fi

if [ "$b" = "y" ]; then
	GIT_VER=$(git rev-parse @)
	PREV_ID=$(docker images -f reference=$IMG_NAME:latest --format "{{.ID}}")
	# Start by removing all previous versions of the image
	if [ ! -z "$PREV_ID" ]; then
		docker image rm -f "$PREV_ID"
	fi
	# Build and tag the image with the git commit hash
	printf "Building docker image: $IMG_NAME:$GIT_VER\n"
	docker build -t $IMG_NAME:latest .
	docker tag $IMG_NAME:latest $IMG_NAME:$GIT_VER
fi

if [ "$pushMode" != "-" ]; then
    case "$pushMode" in
        patch)
			 NEW_SEM_VER=$(npm version patch)
            ;;
        minor)
			 NEW_SEM_VER=$(npm version minor)
            ;;
        major)
			 NEW_SEM_VER=$(npm version major)
            ;;
        *)
            printf "push must be one of patch, minor, or major\n"
			exit 1
    esac
	
	printf "New sem version: $NEW_SEM_VER\n"
	
	# Tag the new commit version and remove the old tag
	# (npm version bump creates a new commit)
	NEW_GIT_VER=$(git rev-parse @)
	PREV_GIT_VER=$(git rev-parse @~)
	docker tag $IMG_NAME:latest $IMG_NAME:$NEW_GIT_VER
	docker image rm $IMG_NAME:$PREV_GIT_VER
	
	# Push the newest commit, and latest tag
	printf "Pushing git version to docker repo: $NEW_GIT_VER"
	docker push $IMG_NAME:$NEW_GIT_VER
	printf "Pushing tag latest to docker repo:"
	docker push $IMG_NAME:latest

	# Create the semantic version tag, push it, then remove it
	# from the local system.
	printf "Pushing tag $NEW_SEM_VER to docker repo:"
	docker tag $IMG_NAME:$NEW_GIT_VER $IMG_NAME:$NEW_SEM_VER
	docker push $IMG_NAME:$NEW_SEM_VER
	docker image rm $IMG_NAME:$NEW_SEM_VER
fi

exit 0
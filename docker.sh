#!/bin/bash
# saner programming env: these switches turn some bugs into errors
set -o errexit -o pipefail -o noclobber -o nounset

! getopt --test > /dev/null 
if [[ ${PIPESTATUS[0]} -ne 4 ]]; then
    echo 'I’m sorry, `getopt --test` failed in this environment.'
    exit 1
fi

usage="$(basename "$0") [ -h | --help ] [-i | --info] [ -b | --build ] [ -p | --push ] -- program to build and push docker container images"

help="
where:
    -h, --help    : help
    -i, --info    : get the current projects repo/name
    -b, --build   : build container
    -v, --version : bump the version by 1 (patch, minor, or major) 
    -p, --push    : push a new version"

OPTIONS=hibpv:
LONGOPTS=help,info,build,push,version:,

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

h=n i=n b=n p=n versionBump=-
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
            p=y
            shift
            ;;
        -v|--version)
            versionBump="$2"
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
    printf "$usage\n"
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
        printf "Deleting old docker image:\n"
        docker image rm -f "$PREV_ID"
    fi
    # Build and tag the image with the git commit hash
    printf "\nBuilding new docker image: $IMG_NAME:$GIT_VER\n"
    docker build -t $IMG_NAME:latest .
    docker tag $IMG_NAME:latest $IMG_NAME:$GIT_VER
fi

if [ "$versionBump" != "-" ]; then
    case "$versionBump" in
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
            printf "version bump must be one of patch, minor, or major\n"
            exit 1
            ;;
    esac
    printf "Rebuilding with new semantic version: $NEW_SEM_VER\n\n"
    # Rebuild so that new semantic version is included in the image
    "$0" -b
fi


if [ "$p" = "y" ]; then
    GIT_VER=$(git rev-parse @)
    SEM_VER=$(cat package.json \
        | grep version \
        | head -1 \
        | awk -F: '{ print $2 }' \
        | sed 's/[",]//g' \
        | sed -e 's/^[ \t]*//')

    # Push the newest commit
    printf "Pushing new git version to docker repo: $GIT_VER\n"
    docker push $IMG_NAME:$GIT_VER
    # Push the latest tag
    printf "\nPushing latest tag to docker repo: latest\n"
    docker push $IMG_NAME:latest
    # Create the semantic version tag, push it, then remove it
    # from the local system.
    printf "\nPushing semantic version tag to docker repo: v$SEM_VER\n"
    docker tag "$IMG_NAME":"$GIT_VER" "$IMG_NAME":"v$SEM_VER"
    docker push "$IMG_NAME":"v$SEM_VER"
    docker image rm "$IMG_NAME":"v$SEM_VER"
fi

exit 0
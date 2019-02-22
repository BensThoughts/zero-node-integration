# Zero Node/Angular Integration

This is slightly opinionated script that I wrote to aid in building and pushing docker images to registries in which package.json is used for versioning.  In other words this works for Node and Angular apps. Specifically I use it with google image registry, but I'm sure you could use it with others.

It will automatically build docker images locally, keeping the most recent version tagged with recent, and the commit hash it is based on. This makes testing locally easy.  When you are ready to release you can push the image to your registry with a new version number tag, (patch, minor, or major), the git commit tag it is based on, and the recent tag.  This makes keeping track of versions, the commit hash they came from, and which is the most recent very easy.  

***How to setup:***

Make sure you have a file in your project directory called deploy.env next to docker.sh, as well as a Dockerfile and a package.json file.  You will also need npm for the automatic version bumping.

deploy.env looks like:

```
DOCKER_REPO=gcr.io/my-project
APP_NAME=myapp
```

Enable docker.sh from a command prompt with:
```
# chmod +x docker.sh
```

Get help with:
```
# ./docker.sh -h || --help
```

Check that the repo and app name are set correctly:
```
# ./docker.sh -i || --info
```

***What is does:***


**--build || -b:** 

***Note*** If you are running the container you will need to remove it before building.  Just stop the container from running then run --build again.

The --build command will remove the latest image and all of it's tags, build a new version on your local system based on your latest commit, tag it with the current git commit hash and latest.

You can test the latest built image with docker run or with docker-compose by referencing the latest image:
```
docker container run DOCKER_REPO/APP_NAME:latest
```
or for example:
```
services:
    your-app:
        image: DOCKER_REPO/APP_NAME:latest
```

**--push || -p [patch, minor, or major]** 

***Note*** You will need to authenticate your docker to the image registry you are using before push will work.  This can be done in various ways, for google it is:

```
# gcloud auth configure-docker
```

In general --push is meant to be used for releases, so you should be at a clean stage in which your app is fully up to date, recently committed, and recently built, or pushing will not work.

***Note*** If you get an error such as:
```
Error: No such image: gcr.io/zero-inbox-organizer/zeroinbox-api:commitHash
```
It is because you are trying to push an image that is not based on the latest commit. --build the image and the try push again.

***Note*** If you get an error such as
```
npm ERR! Git working directory not clean.
```
It is because you have uncommitted files. Commit your changes, --build the image, and then try --push again.

The --push command will use npm to bump the version stored in your package.json file by one in either the major X.0.0, minor 0.Y.0, or patch 0.0.Z field. You can do this with --push patch, --push minor, or --push major.

***Note*** The version bump feature of npm also creates a new commit with a tag of the new version that looks like v.X.Y.Z in the git tree, to mark the release. After the version bump the script will re-tag the image on your local machine so that the recent hash reflects the new semantic version commit hash.  It will then push the most recent image that you built to your repo and tag it with it's git commit hash, recent, and the semantic version.


**Overview:**

In total you can work on a project, wile committing changes.  Then test those changes locally by using --build and running the container.  Then when you are ready to release (i.e. have commited all the latest changes and built them into an image) --push the changes to your docker repo with the appropriate new version bump.

Your docker image repo will continue to grow with the recent tag remaining attached to the most recent version/commit while leaving behind images that have a semantic version tag as well as a commit hash tag.

Thus in your image repo it is easy to see what version images are associated with and to look up from which commit they came from. While on your local machine being able to commit and test regularly without having each new commit pollute your system.

All the while you will not have to manually edit your package.json to bump the version.
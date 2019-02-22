# Zero Node/Angular Integration

This is a slightly opinionated script that I wrote to aid in building and pushing docker images to registries in which package.json is used for versioning.  This works for Node, Angular, or any other apps that use package.json for versioning (There is an example angular Dockerfile in the repo as well). Specifically I use it with google image registry, but I'm sure you could use it with others.

It will automatically build docker images locally, keeping the most recent version tagged with recent and the commit hash it is based on. It will clean up older versions from the local image store as it goes. This makes testing locally easy. 

When you are ready to release you can bump the version automatically and push the image to your registry with a new semantic version tag (patch, minor, or major), the git commit hash it is based on, and the recent tag.  This makes keeping track of versions in your registry, the commit hash they came from, and which is the most recent very easy.

# How to setup:

**Dependendcies:**

* npm
* git
* docker

Download docker.sh from this repo to your project directory. Enable it from a command prompt:
```
# chmod +x docker.sh
```

Make sure you also have a file in your project directory called deploy.env.

deploy.env looks like:

```
DOCKER_REPO=gcr.io/my-project
APP_NAME=myapp
```

In total you should have the dependencies installed, as well as a Dockerfile, package.json, docker.sh, and deploy.env all in the the primary directory that git was initialized in for the project. deploy.env keeps the configuration separate from the script so that it is easy to use this within any project.

Get help with:
```
# ./docker.sh -h || --help
```

Check that the repo and app name are set correctly:
```
# ./docker.sh -i || --info
```

# What is does:

**--build || -b :** Builds the image for local testing

***Note*** If you are running the container you will need to remove it before building.  Just stop the container from running then run --build again.

The --build command will remove the latest image and all of it's tags, build a new version on your local system based on your current commit, tag it with the current git commit hash and latest.

***Note*** If you have multi-stage builds, \<NONE\> image tags will be left behind. These can be easily cleaned up with *docker image prune*.

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

**--version || -v [patch, minor, or major] :** Bumps the semantic version up 1 and then rebuilds

--version will use npm to bump the semantic version stored in your package.json file by 1, in either the major X.0.0, minor 0.Y.0, or patch 0.0.Z field. You can do this with --version patch, --version minor, or --version major.

***Note*** The version bump feature of npm also creates a new git tag that looks like v.X.Y.Z in the git tree, to mark the release. 

After the version bump the script will re-build the image so that the new semantic version is reflected inside of the image.

***Note*** If you get an error such as
```
npm ERR! Git working directory not clean.
```

It is because you have uncommitted files. Commit your changes, and then try to --version again.


**--push || -p :** Pushes the image to the registry with the tags: latest, git commit hash, and current semantic version.

***Note*** You will need to authenticate your docker to the image registry you are using before push will work.  This can be done in various ways, for google it is:

```
# gcloud auth configure-docker
```

In general --push is meant to be used for releases, so you should be at a clean stage in which your app is fully up to date, recently committed and built, or pushing will not work.

**Note** If you get an error such as
```
tag does not exist: DOCKER_REPO/APP_NAME:commitHash
```

It is because you have not built the image based on the latest commit.  Suggestion is to run --version to bump the version (this will automatically build out the latest version), or just run --build if you do not want to bump the version before pushing.


# Overview of workflow:

You can work on a project, wile committing changes. Then test those changes locally by using --build and running the container.

When you are ready to release (i.e. have committed all of the latest changes and built them into an image) bump the version with --version so that your image reflects the new version in its package.json.

Then use --push to push the new version along with its associated tags (latest, git commit hash, and semantic version) to your docker registry.


# Benefits:

Your docker image repo will continue to grow with the recent tag remaining attached to the most recent version/commit while leaving behind images that have a semantic version tag as well as a commit hash tag.

Thus in your image repo it is easy to see what version images are and to look up which commit they came from. All the while on your local machine it is easy to commit and test regularly without having each new commit build pollute your system.

And lastly you will not have to manually edit your package.json to bump the version when you release.
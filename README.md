# Zero Node Integration

This is a small script I wrote to aid in building and pushing docker images based on node.js.  Specifically I use it with google image registry, but I'm sure you could use it with others.

***How to setup:***

Make sure you have a file in your project directory called deploy.env next to docker.sh, as well as a Dockerfile.

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


**--build || -b:** This will build a new version on your local system, tag it with the current git commit hash as well as latest.  If a pervious version already exists it will remove it, so as you continue to commit to git and build you will only see the latest built image and it's git commit hash to mark where in the git tree the build came from.  It cleans up after itself.

**--push || -p [patch, minor, or major]** This will use npm to bump the version stored in your package.json file by one in either the major X.0.0, minor 0.Y.0, or patch 0.0.Z field. The version bump feature of npm also creates a new commit with a tag of the new version that looks like v.X.Y.Z in the git tree. After the version bump the script will relabel the image on your local machine so that the recent hash reflects the new commit hash.  It will then push the most recent image to your repo and tag it with it's git commit hash, recent, and the semantic version.

So in total you can work on a project, wile committing changes.  Then test those changes locally by using --build and running the container.  Then when you are ready to release --push the changes to your docker repo with the appropriate new version bump.

Your docker image repo will continue to grow with the recent tag remaining attached to the most recent version/commit while leaving behind images that have a semantic version tag as well as a commit hash tag.

Thus in your image repo it is easy to see what version images are associated with in the repo and to look up from which commit they came from. While on your local machine being able to commit and test regularly without having each new commit pollute your system.

All the while you will not have to manually edit your package.json at all.
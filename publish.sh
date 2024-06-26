#!/bin/sh
set -e

# Collect some variables
dist_tag=${NPM_DIST_TAG:-dev}
package_name=${NPM_PACKAGE_NAME}
dry_run=${DRY_RUN:-1}

# Create a temporary working directory to avoid dirty files in after publish
workdir=$(mktemp -d -t signify-publish-XXXXXXXXXXXXXXm)
rsync -r --exclude-from=".gitignore" . "$workdir"
cd "$workdir"

echo ""
echo "Created temporary working directory $PWD"

# Make sure there are no git status changes
if [ -n "$(git status -u --porcelain)" ]; then
    echo ""
    echo "The workspace is modified, are you sure? yes/no"
    read -r REPLY
    echo

    if [ "$REPLY" != "yes" ]; then
        exit 1
    fi
fi

# Installing dependencies from lockfile
npm ci --ignore-scripts

# Setting package name (e.g. publishing a fork package)
if [ -n "$package_name" ]; then
    echo "Changing package name to $package_name"

    jq -r ".name = \"$package_name\"" package.json >package.json.tmp
    mv package.json.tmp package.json
fi
package_name=$(jq .name -r package.json)

# Determine which version to publish
if [ "$dist_tag" = "dev" ]; then
    version=$(jq .version -r package.json)-dev.$(git rev-parse --short HEAD)
    npm version --no-git-tag-version "$version"
else
    version=$(jq .version -r package.json)
fi

echo ""
echo "Getting ready to publish version $package_name@$version"
if [ -z "$dry_run" ] || [ "$dry_run" -eq "0" ]; then
    echo "Are you sure? yes/no"
    read -r REPLY
    echo

    if [ "$REPLY" = "yes" ]; then
        git tag "v$version"
        npm publish --tag "$dist_tag"
        git push origin "v$version"
    else
        echo "Exiting without publish"
        exit 0
    fi
else
    npm publish --tag "$dist_tag" --dry-run
fi

echo ""
echo "All done, cleaning up working directory $workdir"
rm -rf "$workdir"

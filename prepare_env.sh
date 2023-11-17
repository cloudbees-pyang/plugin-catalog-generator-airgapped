#!/usr/bin/env sh

set -euo pipefail

set -x

show_help() {
cat << EOF
Usage: ${0##*/} -v <CI_VERSION> [-h]

    -h          display this help and exit
    -v          the version of the CloudBees CI controller
EOF
}

if [[ ${#} -eq 0 ]]; then
   show_help
   exit 0
fi

OPTIND=1
# Resetting OPTIND is necessary if getopts was used previously in the script.
# It is a good idea to make OPTIND local if you process options in a function.

while getopts :h:v: opt; do
    case $opt in
        h)
            show_help
            exit 0
            ;;
        v)  CONTROLLER_VERSION=$OPTARG
            ;;
        *)
            show_help >&2
            exit 1
            ;;
    esac
done
shift "$((OPTIND-1))"   # Discard the options and sentinel --

SCRIPT_PATH=script_v$CONTROLLER_VERSION

rm -rf $SCRIPT_PATH
mkdir $SCRIPT_PATH

cp local_run_json.sh ./$SCRIPT_PATH/
cp local_run_yaml.sh ./$SCRIPT_PATH/
echo "export CONTROLLER_VERSION=$CONTROLLER_VERSION" >> ./$SCRIPT_PATH/.version.sh

curl -L https://jenkins-updates-cdn.cloudbees.com/update-center/envelope-core-mm/update-center.json?version=$CONTROLLER_VERSION -o ./$SCRIPT_PATH/update-center.json
sed -i '' -e '1 d' ./$SCRIPT_PATH/update-center.json
sed -i '' -e '$ d' ./$SCRIPT_PATH/update-center.json

curl -L https://jenkins-updates-cdn.cloudbees.com/update-center/core-mm-experimental/update-center.json?version=$CONTROLLER_VERSION -o ./$SCRIPT_PATH/update-center-experimental.json
sed -i '' -e '1 d' ./$SCRIPT_PATH/update-center-experimental.json
sed -i '' -e '$ d' ./$SCRIPT_PATH/update-center-experimental.json

curl -L https://updates.jenkins.io/plugin-versions.json?version=$CONTROLLER_VERSION -o ./$SCRIPT_PATH/plugin-versions.json

CB_DOCKER_IMAGE=${CB_DOCKER_IMAGE:="cloudbees/cloudbees-core-mm"}
CONTAINER_ID=$(docker create $CB_DOCKER_IMAGE:$CONTROLLER_VERSION 2>/dev/null) 2>/dev/null
docker cp $CONTAINER_ID:/usr/share/jenkins/jenkins.war ./$SCRIPT_PATH/jenkins.war 2>/dev/null
docker rm $CONTAINER_ID >/dev/null 2>&1

JAR_URL=$(curl -sL \
    -H "Accept: application/vnd.github.v3+json" \
    https://api.github.com/repos/jenkinsci/plugin-installation-manager-tool/releases/latest \
    | yq e '.assets[0].browser_download_url' -)
curl -sL $JAR_URL > ./$SCRIPT_PATH/jenkins-plugin-manager.jar

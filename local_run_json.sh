#!/usr/bin/env sh

#set -euo pipefail

set -x

show_help() {
cat << EOF
Usage: ${0##*/} -v <CI_VERSION> -r <LOCAL_ARTIFACTORY_URL> [-h] [-x]

    -h          display this help and exit
    -f FILE     path to the plugins.yaml file
    -p          path to the plugin management tool lib 
    -w          path to the jenkins.war file
    -u          the FULL path to the update_center.json file
    -e          the FULL path to the experiemental update_center.json file
    -i          the FULL path to the plugin-versions.json file
    -v          the version of the CloudBees CI controller
    -r          the url of local proxy artifactory repository
EOF
}

if [[ ${#} -eq 0 ]]; then
   show_help
   exit 0
fi

source ./.version.sh
PLUGIN_MANAGEMENT_TOOL_PATH="./jenkins-plugin-manager.jar"
PLUGIN_YAML_PATH="./plugins.yaml"
JENKINS_WAR_PATH="./jenkins.war"
UPDATE_CENTER_JSON_FULL_PATH="$(pwd)/update-center.json"
UPDATE_CENTER_EXPERIEMENTAL_JSON_FULL_PATH="$(pwd)/update-center-experimental.json"
JENKINS_PLUGIN_INFO_FULL_PATH="$(pwd)/plugin-versions.json"

# echo "update center url: $UPDATE_CENTER_JSON_FULL_PATH"

OPTIND=1
# Resetting OPTIND is necessary if getopts was used previously in the script.
# It is a good idea to make OPTIND local if you process options in a function.

while getopts :h:p:f:w:u:e:i:r:v: opt; do
    case $opt in
        h)
            show_help
            exit 0
            ;;
        p)  PLUGIN_MANAGEMENT_TOOL_PATH=$OPTARG
            ;;
        f)  PLUGIN_YAML_PATH=$OPTARG
            ;;
        w)  JENKINS_WAR_PATH=$OPTARG
            ;;
        u)  UPDATE_CENTER_JSON_FULL_PATH=$OPTARG
            ;;
        e)  UPDATE_CENTER_EXPERIEMENTAL_JSON_FULL_PATH=$OPTARG
            ;;
        i)  JENKINS_PLUGIN_INFO_FULL_PATH=$OPTARG
            ;;
        r)  LOCAL_PLUGIN_REPOSITORY_URL=$OPTARG
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

rm -f .plugin.yaml .plugin-catalog .plugin-catalog.json plugin-catalog.yaml plugin-catalog.json

sed 's/id:/artifactId:/g' $PLUGIN_YAML_PATH >> .plugin.yaml

#being writing the plugin-catalog
echo "{
    \"type\" : \"plugin-catalog\",
    \"version\" : \"1\",
    \"name\" : \"plugin-catalog-$CONTROLLER_VERSION\",
    \"displayName\" : \"plugin-catalog-$CONTROLLER_VERSION\",
    \"configurations\" : [
        {
            \"description\" : \"My Plugin Catalog for Masters version $CONTROLLER_VERSION\",
            \"prerequisites\": {
                \"productVersion\": \"[$CONTROLLER_VERSION]\"
            },
            \"includePlugins\" : {" > .plugin-catalog.json

export JENKINS_UC_HASH_FUNCTION="SHA1"

java -jar $PLUGIN_MANAGEMENT_TOOL_PATH \
--no-download --verbose --jenkins-update-center file:$UPDATE_CENTER_JSON_FULL_PATH \
--jenkins-experimental-update-center file:$UPDATE_CENTER_EXPERIEMENTAL_JSON_FULL_PATH \
--jenkins-plugin-info file:$JENKINS_PLUGIN_INFO_FULL_PATH \
--list --war $JENKINS_WAR_PATH \
--plugin-file .plugin.yaml \
2>&1 >/dev/null \
| sed -n '/^Plugins\ that\ will\ be\ downloaded\:$/,/^Resulting\ plugin\ list\:$/p' \
| sed '1d' | sed '$d' | sed '$d' \
>> .plugin-catalog

cat .plugin-catalog | while read name version; do
    echo "\"$name\": {
        \"url\": \"$LOCAL_PLUGIN_REPOSITORY_URL/$name/$version/$name.hpi\"
        }," >> .plugin-catalog.json

done

sed '$ s/.$//' .plugin-catalog.json > plugin-catalog.json

echo "
       }
    }
  ]
}
" >> plugin-catalog.json



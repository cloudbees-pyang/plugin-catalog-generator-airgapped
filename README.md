# plugin-catalog-generator-airgapped
The scripts used to generate plugin catalog for Cloudbees CI running in an air gapped environment 

## Scenario

These scripts are developed for the Cloudbees CI administrators who have to manage and maintaining the CloudBees CI in a "pure" air gapped environment. Here "pure" means that not only the CloudBees CI product itself running on the network isolated infrastructures, but the CloudBees CI administrators have to work with computers without Internet access (e.g. they can only download the software and updates pushed by specific team from an internal file server).  
The reason that these scripts are needed mainly because the BeeKeeper can only manage the tier1 and tier2 plugins in an air gapped environment, and we usually recommand the Cloudbees CI users manage the tier3 plugins through plugin catalog and proxy artifactory repositary, which have no dependency calculation capabilities by default.  

In this case, the CloudBees CI users could use these scripts to generate the plugin catalog file in either json or yaml formats which contains the tier3 plugins as well as their dependency plugins as a calculation result, which could be used for jenkins cli or CASC bundles respectively.

The main idea is: 

Give this script a path to a `plugins.yaml` file in a bundle with all plugins you want installed (any tier), and it will:

1. Based on the version of controller, a preparing script could download all of the files needed for dependency calculation and put them in a folder and pushed into users' internal file server
2. The CloudBees CI administrator could download this folder from file server, specify the controller's plugins.yaml file and proxy artifactory repository as parameter, which will execute the script and generate the `plugin-catalog.json` file or 'plugin-catalog.yaml' for you in the same directory, including all versions and transitive dependencies.

This means that as long as you are willing to use the plugin versions in the CloudBees Update Centers (which you should be doing), then all you ever need to do is add plugins to the `plugins.yaml` file and this script will handle the rest. No more manually crafting plugin catalogs!

## Requirements

* docker
* curl
* JDK 11

## Usage

1. prepare_env.sh (need Internet connection)

```
Usage: ${0##*/} -v <CI_VERSION> [-h]

    -h          display this help and exit
    -v          the version of the CloudBees CI controller
```

2.local_run_json.sh or local_run_yaml.sh (run in air gapped environment)

```
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
```

## Examples

For example, if you want to install two tier 3 plugins with id "plugin-1" and "plugin-2" in your controller with version 2.319.3.4. This is what you need to do

1. In a connected environment, run "prepare_env.sh" to prepare a folder with all necessary files to generate the plugin catalog file:

'./prepare_env.sh -v 2.319.3.4' 

A folder with name "script-2.319.3.4" will be created with all files downloaded for next step. Then this folder could be packaged and upload into your internal file server in some way.

2. Export the plugins.yaml file from your controller, and append the plugins that you want to install in this file:

' ......
- id: plugin-1
- id: plugin-2
'

3. Download the folder "script-2.319.3.4" from your internal file server, copy the modified plugins.yaml file into it, and execute the local_run_json.sh or local_run_yaml.sh: 

'./local_run_json.sh -r "https://10.10.10.10/plugins"
or 
'./local_run_yaml.sh -r "https://10.10.10.10/plugins"

You need to specify the url of your proxy artifactory repository (e.g. Nexus) with -r parameter. 



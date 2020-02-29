# GCP + Codeship Continuous Deployment/Delivery

Taking advantage of GCP git deployment for more flexiblity to deploy multiple extension and skin repos automatically to [GCP .git deployment](https://kinsta.com/git/) using [Codeship](https://codeship.com) or other deployment services.

At [Woxmat](https://woxmat.com) we use [GCP](https://cloud.google.com) and [Codeship](https://www.codeship.com) for our continuous integration and continuous delivery (CICD) pipelines and they are both AWESOME. It is useful for our efficiency.

# Release Candidate 1.0

### The instructions and the deployment script assumes the following

* Codeship is the CI/CD solution of choice. You may need to make adjustments based on DeployBot or another service.
* You understand how to setup [.git deployments on GCP](https://cloud.google.com/git/) already.
* The repo's **master** branch is used for **production**
* The repo's **develop** branch is used for **staging**

### Setup

* [Preflight Repo Setup](https://github.com/officialwoxmat/kinsta-codeship-continuous-deployment#preflight-repo-setup)
* [Configuration](https://github.com/officialwoxmat/kinsta-codeship-continuous-deployment#configuration)
* [Codeship Environment Variables](https://github.com/officialwoxmat/kinsta-codeship-continuous-deployment#codeship-environment-variables)
* Deployment instructions
* [Useful notes](https://github.com/officialwoxmat/kinsta-codeship-continuous-deployment#useful-notes)
* What this repo needs

### Preflight Repo Setup

When creating your repo, it's important to name the repo using proper folder structure. Any spaces " " are replaced with dashes "-". **Example:** your plugin named "Awesome Plugin" can become the repo "awesome-plugin". `REPO_NAME` environment variable is used when deploy script is run as the folder for your extension or skin. So you may find it useful to match.

**Important Note:** All assets/files within your repo should be within the root folder. **THE DEPLOY SCRIPT WILL CREATE ALL APPROPRIATE FOLDERS NEEDED SO DO NOT INCLUDE CORE FOLDERS**.

### Configuration

1. Log into **codeship.com** or your deployment method of choice.
2. Connect your **bitbucket**, **github** or **gitlab** repo to codeship. (You will need to authorize access to your repo)
3. Setup [Environment Variables](https://github.com/officialwoxmat/kinsta-codeship-continuous-deployment#codeship-environment-variables)
    * Environment variables add flexibility to the deploy script without having sensitive variables within this deployment.
    * Never have any credentials stored within this or any other repository.
4. Create deployment pipeline for each branch you are going to add automated deployments to **"master"** and **"staging"**. The pipelines you create are going to utilize the **DEPLOYMENT SCRIPT BELOW**
5. Test a git push to the repo. 1st time this happens within Codeship it may be beneficial to watch all the steps that are displayed within their helpful console.

### Codeship Environment Variables

All of the environment variables below are required

|Variable|Description|Required|
| ------------- | ------------- | ------------- |
|**REPO_NAME**|The repo name should match the theme / plugin folder name|:heavy_exclamation_mark:|
|**WPE_INSTALL**|The subdomain from GCP|:heavy_exclamation_mark:|
|**PROJECT_TYPE**|(**"theme"** or **"plugin"**) This really just determines what folder your repo is in|:heavy_exclamation_mark:|
|**EXCLUDE_LIST**|Custom list of files/directories that will be used to exclude files from deploymnet. This deploy script provides a default. This environment variable is only needed if you are customizing for your own usage. This variable should be a FULL URL to a file. See exclude-list.txt for an example| Optional

### Commit Message Hash Tags
You can customize the actions taken by the deployment script by utilizing the following hashtags within your commit message

|Commit #hashtag|Description|
| ------------- | ------------- |
|**#force**|Some times you need to disregard what GCP has within their remote repo(s) and start fresh. [Read more](https://wpengine.com/support/resetting-your-git-push-to-deploy-repository/) about it on WP Engine.|

## Deployment Instructions (The Script)

The below build script(s) will check out the officialwoxmat deploy script from github and then run it accordingly based on the environment variables.

In the script below you will see this script is specifcally for **master** if you wanted to use this for staging you would setup a deployment that targets **develop** specifically.

### deploying to your pipeline (master|develop)

Deploy to your pipeline with the following command regardless of master, develop or a custom branch. `https` is used here instead of `SSH` so we can `git clone` the deployment script without authentication.

```
# load our build script from the officialwoxmat repo
git clone --branch "master" --depth 50 https://github.com/officialwoxmat/kinsta-codeship-continuous-deployment.git
chmod 555 ./kinsta-codeship-continuous-deployment/deploy.sh
./kinsta-codeship-continuous-deployment/deploy.sh
```

## Useful Notes
* WP Engine's .git push can almost be considered a "middle man" between your repo and what is actually displayed to your visitors within the root web directory of your website. After the files are .git pushed to your production or staging remote branches they are then synced to the appropriate environment's webroot. It's important to know this because there are scenarios where you may need to use the **#force** hashtag within your commit message in order to override what WP Engine is storing within it's repo and what is shown when logged into SFTP. You can read more about it on [WP Engine](https://wpengine.com/support/resetting-your-git-push-to-deploy-repository/)

* If an SFTP user in WP Engine has uploaded any files to staging or production those assets **WILL NOT** be added to the repo.
* Additionally there are times where files need to deleted that are not associated with the repo. In these scenarios we suggest deleting the files using SFTP and then utilizing the **#force** hash tag within the next deployment you make.

### What does this repo need

* Tests and Validation
* Peer review
* Complete documentation for usage (setup pipelines, testing etc).

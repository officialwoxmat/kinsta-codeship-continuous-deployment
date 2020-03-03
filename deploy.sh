#!/bin/bash
# If any commands fail (exit code other than 0) entire script exits
set -e

# Check for required environment variables and make sure they are setup
: ${PROJECT_TYPE?"PROJECT_TYPE Missing"} # theme|plugin
: ${REPO_INSTALL?"REPO_INSTALL Missing"}   # subdomain for kinsta install 
: ${REPO_PASS?"REPO_PASS Missing"}       # repo pass (Typically the password to your CVS)
: ${REPO_USER?"REPO_USER Missing"}       # repo user (Typically the username of your CVS)
: ${REPO_NAME?"REPO_NAME Missing"}       # repo name (Typically the folder name of the project)
: ${SSH_NAME?"SSH_NAME Missing"} # SSH username
: ${SSHPASS?"SSHPASS Missing"} # SSH Password (Used by sshpass as environment variable) 
: ${SSH_IP?"SSH_IP Missing"}   # SSH IP/Domain 
: ${SSH_PORT?"SSH_PORT Missing"}       # SSH Port (Typically the port # of the Stage)
: ${STAGE_ROOT?"STAGE_ROOT Missing"}       # Stage Folder (Typically the folder name of the Stage)

# Set repo based on current branch, by default master=production, develop=staging
# @todo support custom branches
if [ "$CI_BRANCH" == "master" ]
then
    repo=production
else
    repo=staging
fi

# Begin from the ~/clone directory
# this directory is the default your git project is checked out into by Codeship.
cd ~/clone

# Get official list of files/folders that are not meant to be on production if $EXCLUDE_LIST is not set.
if [[ -z "${EXCLUDE_LIST}" ]];
then
    wget https://raw.githubusercontent.com/officialwoxmat/kinsta-codeship-continuous-deployment/master/exclude-list.txt
else
    # @todo validate proper url?
    wget ${EXCLUDE_LIST}
fi

# Loop over list of files/folders and remove them from deployment
ITEMS=`cat exclude-list.txt`
for ITEM in $ITEMS; do
    if [[ $ITEM == *.* ]]
    then
        find . -depth -name "$ITEM" -type f -exec rm "{}" \;
    else
        find . -depth -name "$ITEM" -type d -exec rm -rf "{}" \;
    fi
done

# Remove exclude-list file
rm exclude-list.txt

# Clone the WPEngine files to the deployment directory
# if we are not force pushing our changes
if [[ $CI_MESSAGE != *#force* ]]
then
    force=''
#    git clone git@git.kinsta.com:${repo}/${REPO_INSTALL}.git ~/deployment
    git clone https://${REPO_USER}:${REPO_PASS}@github.com/${REPO_NAME}/${REPO_INSTALL}.git ~/deployment
else
    force='-f'
    if [ ! -d "~/deployment" ]; then
        mkdir ~/deployment
        cd ~/deployment
        git init
    fi
fi

# If there was a problem cloning, exit
if [ "$?" != "0" ] ; then
    echo "Unable to clone ${repo}"
    kill -SIGINT $$
fi

# Move the gitignore file to the deployments folder
cd ~/deployment
wget --output-document=.gitignore https://raw.githubusercontent.com/officialwoxmat/kinsta-codeship-continuous-deployment/master/gitignore-template.txt

# Delete plugin/theme if it exists, and move cleaned version into deployment folder
rm -rf /wp-content/${PROJECT_TYPE}s/${REPO_NAME}

# Check to see if the wp-content directory exists, if not create it
if [ ! -d "./wp-content" ]; then
    mkdir ./wp-content
fi
# Check to see if the plugins directory exists, if not create it
if [ ! -d "./wp-content/plugins" ]; then
    mkdir ./wp-content/plugins
fi
# Check to see if the themes directory exists, if not create it
if [ ! -d "./wp-content/themes" ]; then
    mkdir ./wp-content/themes
fi

rsync -a ../clone/* ./wp-content/${PROJECT_TYPE}s/${REPO_NAME}

# Install sshpass
sudo apt-get install sshpass

sshpass -e ssh -o "StrictHostKeyChecking=no" ${SSH_NAME}@${SSH_IP} -p ${SSH_PORT} "cd /www/${STAGE_ROOT} && rm -rf private/ && git clone --branch develop https://${REPO_USER}:${REPO_PASS}@github.com/${REPO_NAME}/${REPO_INSTALL}.git ~/private"
git remote add ${repo} https://${REPO_USER}:${REPO_PASS}@github.com/${REPO_NAME}/${REPO_INSTALL}.git
# sshpass -e ssh -o "StrictHostKeyChecking=no" ${SSH_NAME}@${SSH_IP} -p ${SSH_PORT} "git init --bare /www/${STAGE_ROOT}/private/${REPO_NAME}.git"
# git remote add ${repo} ssh://${SSH_NAME}@${SSH_IP}:${SSH_PORT}/www/${STAGE_ROOT}/private/${REPO_NAME}.git
# git remote add ${repo} git@git.kinsta.com:${repo}/${REPO_INSTALL}.git

# stage, commit, and push to custom GCP repo
git config --global user.email CI_COMMITTER_EMAIL
git config --global user.name CI_COMMITTER_NAME
git config core.ignorecase false
git add --all
git commit -am " User $CI_COMMITTER_NAME deploying to ${REPO_INSTALL} $repo from $CI_NAME - Build $CI_BUILD_ID (Commit $CI_COMMIT_ID)"
git rm --cached wp-content/${PROJECT_TYPE}s/${REPO_NAME}/kinsta-codeship-continuous-deployment

# sshpass -e git push ${force} --set-upstream ${repo} master
sshpass -e git push -f --set-upstream ${repo} master

# ssh -o "PubkeyAuthentication=no" ${SSH_NAME}@${SSH_IP} -p ${SSH_PORT} "cd /www/${STAGE_ROOT}/public && git clone origin/master https://${REPO_USER}:${REPO_PASS}@github.com/${REPO_NAME}/${REPO_INSTALL}.git && git reset –hard $CI_COMMIT_ID"
sshpass -e ssh -o "StrictHostKeyChecking=no" ${SSH_NAME}@${SSH_IP} -p ${SSH_PORT} "cd /www/${STAGE_ROOT}/public && rm -rf ${REPO_NAME} && git pull --rebase https://${REPO_USER}:${REPO_PASS}@github.com/${REPO_NAME}/${REPO_INSTALL}.git"

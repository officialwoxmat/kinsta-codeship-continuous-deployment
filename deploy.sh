#!/bin/bash
set -e

: ${PROJECT_TYPE?"PROJECT_TYPE Missing"} 
: ${REPO_INSTALL?"REPO_INSTALL Missing"} 
: ${REPO_PASS?"REPO_PASS Missing"}       
: ${REPO_USER?"REPO_USER Missing"}       
: ${REPO_NAME?"REPO_NAME Missing"}       
: ${SSH_NAME?"SSH_NAME Missing"}         
: ${SSHPASS?"SSHPASS Missing"}           
: ${SSH_IP?"SSH_IP Missing"}             
: ${SSH_PORT?"SSH_PORT Missing"}         
: ${STAGE_ROOT?"STAGE_ROOT Missing"}     

if [ "$CI_BRANCH" == "master" ]
then
    repo=production
else
    repo=staging
fi

cd ~/clone
wget --output-document=.gitignore https://raw.githubusercontent.com/officialwoxmat/kinsta-codeship-continuous-deployment/master/gitignore-template.txt

if [[ -z "${EXCLUDE_LIST}" ]];
then
    wget https://raw.githubusercontent.com/officialwoxmat/kinsta-codeship-continuous-deployment/master/exclude-list.txt
else
    wget ${EXCLUDE_LIST}
fi

ITEMS=`cat exclude-list.txt`
for ITEM in $ITEMS; do
    if [[ $ITEM == *.* ]]
    then
        find . -depth -name "$ITEM" -type f -exec rm "{}" \;
    else
        find . -depth -name "$ITEM" -type d -exec rm -rf "{}" \;
    fi
done

rm exclude-list.txt
if [ -d "./kinsta-codeship-continuous-deployment" ]; then
    rm -fvr ./kinsta-codeship-continuous-deployment
    rm -fvr .git/modules/kinsta-codeship-continuous-deployment
    git rm -fr ./kinsta-codeship-continuous-deployment/*
fi

git config --global user.email "noreply@woxmat.com"
git config --global user.name "Woxmat Bld"
git config --global core.ignorecase false
git ls-files . --exclude-standard --others
if [ "$?" == "0" ]
then
    git add --all
    SUBS=$(git ls-files --stage | grep "^160000 " | perl -ne 'chomp;split;print "$_[3]\n"')
    if [ -z "$SUBS" ]
    then
        echo "======================**[ No Submodules in Parent Repository ]**======================"
    else
        for SUB in $SUBS; do
            git submodule deinit -f -- $SUB     
            rm -rf .git/modules/$SUB            
            git rm -f $SUB                      
            echo "======================**[ Submodule $SUB Removed ]**======================"
        done
    fi
    git commit -am "$CI_REPO_NAME:$CI_BRANCH updated by $CI_COMMITTER_NAME($CI_COMMITTER_USERNAME) with Composer Commit ($CI_COMMIT_ID) from $CI_NAME --skip-ci"
    git pull --rebase origin $CI_BRANCH               
    git push --force-with-lease origin HEAD:$CI_BRANCH
else
    echo "======================**[ No Changes Since Last Deployment Build ]**======================"
fi

if [[ $CI_MESSAGE != *#force* ]]
then
    force=''
    #git clone git@git.kinsta.com:${repo}/${REPO_INSTALL}.git ~/deployment
    git clone https://${REPO_USER}:${REPO_PASS}@github.com/${REPO_NAME}/${REPO_INSTALL}.git ~/deployment
else
    force='-f'
    if [ ! -d "~/deployment" ]; then
        mkdir ~/deployment
        cd ~/deployment
        git init
    fi
fi

if [ "$?" != "0" ] ; then
    echo "Unable to Clone ${repo}"
    kill -SIGINT $$
fi

cd ~/deployment
wget --output-document=.gitignore https://raw.githubusercontent.com/officialwoxmat/kinsta-codeship-continuous-deployment/master/gitignore-template.txt

rm -rf /wp-content/${PROJECT_TYPE}s/${REPO_NAME}

if [ ! -d "./wp-content" ]; then
    mkdir ./wp-content
fi
if [ ! -d "./wp-content/plugins" ]; then
    mkdir ./wp-content/plugins
fi
if [ ! -d "./wp-content/themes" ]; then
    mkdir ./wp-content/themes
fi

rsync -a ../clone/* ./wp-content/${PROJECT_TYPE}s/${REPO_NAME}

sudo apt-get install sshpass

sshpass -e ssh -o "StrictHostKeyChecking=no" ${SSH_NAME}@${SSH_IP} -p ${SSH_PORT} "cd /www/${STAGE_ROOT} && rm -rf private/ && git clone --branch develop https://${REPO_USER}:${REPO_PASS}@github.com/${REPO_NAME}/${REPO_INSTALL}.git ~/private"
git remote add ${repo} https://${REPO_USER}:${REPO_PASS}@github.com/${REPO_NAME}/${REPO_INSTALL}.git

git config --global user.email "noreply@woxmat.com"
git config --global user.name "Woxmat Dev"
git config core.ignorecase false
if [ -f "./.gitignore" ]
then
    git add --all
    git commit -am "Deployment to $CI_REPO_NAME:$CI_BRANCH ($repo) by $CI_COMMITTER_NAME($CI_COMMITTER_USERNAME) from $CI_NAME - Build $CI_BUILD_ID (Commit $CI_COMMIT_ID)"
    git push ${force} --set-upstream ${repo} master
else
    echo "======================**[ No Deletes Since Last .gitignore Build ]**======================"
fi
sshpass -e ssh -o "StrictHostKeyChecking=no" ${SSH_NAME}@${SSH_IP} -p ${SSH_PORT} "cd /www/${STAGE_ROOT}/public && rm -rf ${REPO_NAME}_tmp && git clone https://${REPO_USER}:${REPO_PASS}@github.com/${REPO_NAME}/${REPO_INSTALL}.git ${REPO_NAME}_tmp && cp -R ~/public/${REPO_NAME}_tmp/wp-content/. ~/public/wp-content/. && rm -rf ${REPO_NAME}_tmp && rm -rf ~/public/wp-content/${PROJECT_TYPE}s/${REPO_NAME}/.git && rm -rf ~/public/wp-content/${PROJECT_TYPE}s/${REPO_NAME}/kinsta-codeship-continuous-deployment"

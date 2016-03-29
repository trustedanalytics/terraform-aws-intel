#!/bin/bash

# fail immediately on error
set -e

# echo "$0 $*" > ~/provision.log

fail() {
  echo "$*" >&2
  exit 1
}

# Variables passed in from terraform, see aws-vpc.tf, the "remote-exec" provisioner
AWS_KEY_ID=${1}
AWS_ACCESS_KEY=${2}
REGION=${3}
VPC=${4}
BOSH_SUBNET=${5}
IPMASK=${6}
CF_IP=${7}
CF_SUBNET1=${8}
CF_SUBNET1_AZ=${9}
CF_SUBNET2=${10}
CF_SUBNET2_AZ=${11}
BASTION_AZ=${12}
BASTION_ID=${13}
LB_SUBNET1=${14}
CF_SG=${15}
CF_ADMIN_PASS=${16}
CF_DOMAIN=${17}
CF_SIZE=${18}
DOCKER_SUBNET=${19}
INSTALL_DOCKER=${20}
CF_RELEASE_VERSION=${21}
DEBUG=${22}
PRIVATE_DOMAINS=${23}
CF_SG_ALLOWS=${24}
ENV_NAME=${25}
CONSUL_MASTERS=${26}
INSTALL_LOGSEARCH=${27}
LS_SUBNET1=${28}
LS_SUBNET_AZ=${29}
CF_CLIENT_PASS=${30}
OFFLINE_JAVA_BUILDPACK=${31}
CF_BOSHWORKSPACE_REPOSITORY=${32}
CF_BOSHWORKSPACE_BRANCH=${33}
DOCKER_SERVICES_BOSHWORKSPACE_REPOSITORY=${34}
DOCKER_SERVICES_BOSHWORKSPACE_BRANCH=${35}
LOGSEARCH_WORKSPACE_REPOSITORY=${36}
LOGSEARCH_WORKSPACE_BRANCH=${37}
QUAY_USERNAME=${38}
QUAY_PASS=${39}

BACKBONE_Z1_COUNT=COUNT
API_Z1_COUNT=COUNT
SERVICES_Z1_COUNT=COUNT
HEALTH_Z1_COUNT=COUNT
RUNNER_Z1_COUNT=COUNT
BACKBONE_Z2_COUNT=COUNT
API_Z2_COUNT=COUNT
SERVICES_Z2_COUNT=COUNT
HEALTH_Z2_COUNT=COUNT
RUNNER_Z2_COUNT=COUNT

boshDirectorHost="${IPMASK}.1.4"

STEMCELL_VERSION='3104'

cd $HOME
(("$?" == "0")) ||
  fail "Could not find HOME folder, terminating install."


if [[ $DEBUG == "true" ]]; then
  set -x
fi

# Generate the key that will be used to ssh between the bastion and the
# microbosh machine
if [[ ! -f ~/.ssh/id_rsa ]]; then
  ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa
fi

# Prepare the jumpbox to be able to install ruby and git-based bosh and cf repos

release=$(cat /etc/*release | tr -d '\n')
case "${release}" in
  (*Ubuntu*|*Debian*)
    sudo apt-get update -yq
    sudo apt-get install -yq aptitude
    sudo apt-get install -yq build-essential vim-nox git unzip tree \
      libxslt-dev libxslt1.1 libxslt1-dev libxml2 libxml2-dev \
      libpq-dev libmysqlclient-dev libsqlite3-dev \
      g++ gcc make libc6-dev libreadline6-dev zlib1g-dev libssl-dev libyaml-dev \
      libsqlite3-dev sqlite3 autoconf libgdbm-dev libncurses5-dev automake \
      libtool bison pkg-config libffi-dev cmake libgmp-dev docker.io jq
    ;;
  (*Centos*|*RedHat*|*Amazon*)
    sudo yum update -y
    sudo yum install -y epel-release
    sudo yum install -y git unzip xz tree rsync openssl openssl-devel \
    zlib zlib-devel libevent libevent-devel readline readline-devel cmake ntp \
    htop wget tmux gcc g++ autoconf pcre pcre-devel vim-enhanced gcc mysql-devel \
    postgresql-devel postgresql-libs sqlite-devel libxslt-devel libxml2-devel \
    yajl-ruby cmake
    ;;
esac

# Install RVM

if [[ ! -d "$HOME/.rvm" ]]; then
  cd $HOME
  gpg --list-keys
  gpg --import /home/ubuntu/rvm.gpg
  curl -sSL https://get.rvm.io | bash -s stable
fi

cd $HOME

if [[ ! "$(ls -A $HOME/.rvm/environments)" ]]; then
  ~/.rvm/bin/rvm install ruby-2.1.5
fi

if [[ ! -d "$HOME/.rvm/environments/default" ]]; then
  ~/.rvm/bin/rvm alias create default ruby-2.1.5
fi

source ~/.rvm/environments/default
source ~/.rvm/scripts/rvm

gem install bundler --no-ri --no-rdoc --quiet

# Use Bundler to install the gem environment for correct dependency resolution
cat <<EOF > Gemfile
source 'https://rubygems.org'

gem 'bosh_cli', '1.3104.0'
gem 'bosh-bootstrap'
EOF
bundle install

# Workaround 'illegal image file' bug in bosh-aws-cpi gem.
# Issue is already fixed in bosh-aws-cpi-release but no new gems are being published
if [[ ! -f "/usr/local/bin/stemcell-copy" ]]; then
    curl -sOL https://raw.githubusercontent.com/cloudfoundry-incubator/bosh-aws-cpi-release/138b4cac03197af61e252f0fc3611c0a5fb796e1/src/bosh_aws_cpi/scripts/stemcell-copy.sh
    sudo mv ./stemcell-copy.sh /usr/local/bin/stemcell-copy
    chmod +x /usr/local/bin/stemcell-copy
fi

# We use fog below, and bosh-bootstrap uses it as well
cat <<EOF > ~/.fog
:default:
  :aws_access_key_id: $AWS_KEY_ID
  :aws_secret_access_key: $AWS_ACCESS_KEY
  :region: $REGION
EOF

# This volume is created using terraform in aws-bosh.tf
if [[ ! -d "$HOME/workspace" ]]; then
  sudo /sbin/mkfs.ext4 /dev/xvdc
  sudo /sbin/e2label /dev/xvdc workspace
  echo 'LABEL=workspace /home/ubuntu/workspace ext4 defaults,discard 0 0' | sudo tee -a /etc/fstab
  mkdir -p /home/ubuntu/workspace
  sudo mount -a
  sudo chown -R ubuntu:ubuntu /home/ubuntu/workspace
fi

# As long as we have a large volume to work with, we'll move /tmp over there
# You can always use a bigger /tmp
if [[ ! -d "$HOME/workspace/tmp" ]]; then
  sudo rsync -avq /tmp/ /home/ubuntu/workspace/tmp/
fi

if ! [[ -L "/tmp" && -d "/tmp" ]]; then
  sudo rm -fR /tmp
  sudo ln -s /home/ubuntu/workspace/tmp /tmp
fi

# bosh-bootstrap handles provisioning the microbosh machine and installing bosh
# on it. This is very nice of bosh-bootstrap. Everyone make sure to thank bosh-bootstrap
mkdir -p {bin,workspace/deployments/microbosh,workspace/tools}

pushd workspace/deployments

# TODO: Use this stemcell in BOSH workspaces
STEMCELL=~/light-bosh-stemcell-${STEMCELL_VERSION}-aws-xen-hvm-ubuntu-trusty-go_agent.tgz
test -e ${STEMCELL} || wget -O ${STEMCELL} https://bosh.io/d/stemcells/bosh-aws-xen-hvm-ubuntu-trusty-go_agent?v=${STEMCELL_VERSION}

pushd microbosh
create_settings_yml() {
cat <<EOF > settings.yml
---
bosh:
  name: bosh-${VPC}
  stemcell_path: ${STEMCELL}
provider:
  name: aws
  credentials:
    provider: AWS
    aws_access_key_id: ${AWS_KEY_ID}
    aws_secret_access_key: ${AWS_ACCESS_KEY}
  region: ${REGION}
address:
  vpc_id: ${VPC}
  subnet_id: ${BOSH_SUBNET}
  ip: ${boshDirectorHost}
EOF
}

if [[ ! -f "$HOME/workspace/deployments/microbosh/settings.yml" ]]; then
  create_settings_yml
fi

if [[ ! -d "$HOME/workspace/deployments/microbosh/deployments" ]]; then
  bosh bootstrap deploy
fi


rebuild_micro_bosh_easy() {
  echo "Retry deploying the micro bosh, attempting bosh bootstrap delete..."
  bosh bootstrap delete || rebuild_micro_bosh_hard
  bosh bootstrap deploy
  bosh -n target https://${boshDirectorHost}:25555
  bosh login admin admin
}

rebuild_micro_bosh_hard() {
  echo "Retry deploying the micro bosh, attempting bosh bootstrap delete..."
  rm -rf "$HOME/workspace/deployments/microbosh/deployments"
  rm -rf "$HOME/workspace/deployments/microbosh/ssh"
  create_settings_yml
}

# We've hardcoded the IP of the microbosh machine, because convenience
bosh -n target https://${boshDirectorHost}:25555
bosh login admin admin

if [[ ! "$?" == 0 ]]; then
  #wipe the ~/workspace/deployments/microbosh folder contents and try again
  echo "Retry deploying the micro bosh..."
fi
popd

if [[ ! -d 'cf-boshworkspace' ]]; then
  git clone -b ${CF_BOSHWORKSPACE_BRANCH} ${CF_BOSHWORKSPACE_REPOSITORY} cf-boshworkspace
fi

pushd cf-boshworkspace
mkdir -p ssh
gem install bundler
bundle install

# Pull out the UUID of the director - bosh_cli needs it in the deployment to
# know it's hitting the right microbosh instance
DIRECTOR_UUID=$(bosh status --uuid)

# If CF_DOMAIN is set to XIP, then use XIP.IO. Otherwise, use the variable
if [[ $CF_DOMAIN == "XIP" ]]; then
  CF_DOMAIN="${CF_IP}.xip.io"
fi

echo "Install Traveling CF"
if [[ "$(cat $HOME/.bashrc | grep 'export PATH=$PATH:$HOME/bin/traveling-cf-admin')" == "" ]]; then
  curl -s https://raw.githubusercontent.com/trustedanalytics/traveling-cf-admin/master/scripts/installer | bash
  echo 'export PATH=$PATH:$HOME/bin/traveling-cf-admin' >> $HOME/.bashrc
  source $HOME/.bashrc
fi

if [[ ! -f "/usr/local/bin/spiff" ]]; then
  curl -sOL https://github.com/cloudfoundry-incubator/spiff/releases/download/v1.0.3/spiff_linux_amd64.zip
  unzip spiff_linux_amd64.zip
  sudo mv ./spiff /usr/local/bin/spiff
  rm spiff_linux_amd64.zip
fi

# This is some hackwork to get the configs right. Could be changed in the future
/bin/sed -i \
  -e "s/CF_SUBNET1_AZ/${CF_SUBNET1_AZ}/g" \
  -e "s/CF_SUBNET2_AZ/${CF_SUBNET2_AZ}/g" \
  -e "s/LB_SUBNET1_AZ/${CF_SUBNET1_AZ}/g" \
  -e "s/CF_ELASTIC_IP/${CF_IP}/g" \
  -e "s/CF_SUBNET1/${CF_SUBNET1}/g" \
  -e "s/CF_SUBNET2/${CF_SUBNET2}/g" \
  -e "s/LB_SUBNET1/${LB_SUBNET1}/g" \
  -e "s/DIRECTOR_UUID/${DIRECTOR_UUID}/g" \
  -e "s/run.CF_DOMAIN/${CF_DOMAIN}/g" \
  -e "s/apps.CF_DOMAIN/${CF_DOMAIN}/g" \
  -e "s/CF_DOMAIN/${CF_DOMAIN}/g" \
  -e "s/CF_ADMIN_PASS/${CF_ADMIN_PASS}/g" \
  -e "s/CF_CLIENT_PASS/${CF_CLIENT_PASS}/g" \
  -e "s|\(dns:\).*|\1 [${CONSUL_MASTERS}]|" \
  -e "/- IPMASK.0.2/d" \
  -e "s/IPMASK/${IPMASK}/g" \
  -e "s/CF_SG/${CF_SG}/g" \
  -e "s/LB_SUBNET1_AZ/${CF_SUBNET1_AZ}/g" \
  -e "s/ENV_NAME/${ENV_NAME}/g" \
  -e "s/version: \+[0-9]\+ \+# DEFAULT_CF_RELEASE_VERSION/version: ${CF_RELEASE_VERSION}/g" \
  -e "s/backbone_z1:\( \+\)[0-9\.]\+\(.*# MARKER_FOR_PROVISION.*\)/backbone_z1:\1${BACKBONE_Z1_COUNT}\2/" \
  -e "s/api_z1:\( \+\)[0-9\.]\+\(.*# MARKER_FOR_PROVISION.*\)/api_z1:\1${API_Z1_COUNT}\2/" \
  -e "s/services_z1:\( \+\)[0-9\.]\+\(.*# MARKER_FOR_PROVISION.*\)/services_z1:\1${SERVICES_Z1_COUNT}\2/" \
  -e "s/health_z1:\( \+\)[0-9\.]\+\(.*# MARKER_FOR_PROVISION.*\)/health_z1:\1${HEALTH_Z1_COUNT}\2/" \
  -e "s/runner_z1:\( \+\)[0-9\.]\+\(.*# MARKER_FOR_PROVISION.*\)/runner_z1:\1${RUNNER_Z1_COUNT}\2/" \
  -e "s/backbone_z2:\( \+\)[0-9\.]\+\(.*# MARKER_FOR_PROVISION.*\)/backbone_z2:\1${BACKBONE_Z2_COUNT}\2/" \
  -e "s/api_z2:\( \+\)[0-9\.]\+\(.*# MARKER_FOR_PROVISION.*\)/api_z2:\1${API_Z2_COUNT}\2/" \
  -e "s/services_z2:\( \+\)[0-9\.]\+\(.*# MARKER_FOR_PROVISION.*\)/services_z2:\1${SERVICES_Z2_COUNT}\2/" \
  -e "s/health_z2:\( \+\)[0-9\.]\+\(.*# MARKER_FOR_PROVISION.*\)/health_z2:\1${HEALTH_Z2_COUNT}\2/" \
  -e "s/runner_z2:\( \+\)[0-9\.]\+\(.*# MARKER_FOR_PROVISION.*\)/runner_z2:\1${RUNNER_Z2_COUNT}\2/" \
  deployments/cf-aws-${CF_SIZE}.yml

if [[ $OFFLINE_JAVA_BUILDPACK == "true" ]]; then
  sed -i\
    -e "s/^#  - offline-java-buildpack.yml$/  - offline-java-buildpack.yml/" \
    deployments/cf-aws-${CF_SIZE}.yml
fi

if [[ -n "$PRIVATE_DOMAINS" ]]; then
  for domain in $(echo $PRIVATE_DOMAINS | tr "," "\n"); do
    sed -i -e "s/^\(\s\+\)- PRIVATE_DOMAIN_PLACEHOLDER/\1- $domain\n\1- PRIVATE_DOMAIN_PLACEHOLDER/" deployments/cf-aws-${CF_SIZE}.yml
  done
  sed -i -e "s/^\s\+- PRIVATE_DOMAIN_PLACEHOLDER//" deployments/cf-aws-${CF_SIZE}.yml
else
  sed -i -e "s/^\(\s\+\)internal_only_domains:\$/\1internal_only_domains: []/" deployments/cf-aws-${CF_SIZE}.yml
  sed -i -e "s/^\s\+- PRIVATE_DOMAIN_PLACEHOLDER//" deployments/cf-aws-${CF_SIZE}.yml
fi

# generate UAA certificate pair
if grep -q UAAC deployments/cf-aws-${CF_SIZE}.yml; then
  openssl genrsa -out /tmp/uaac_prv.pem 2048
  openssl rsa -pubout -in /tmp/uaac_prv.pem -out /tmp/uaac_pub.pem
  sed -i -e "s/UAAC_PRV_KEY/$(</tmp/uaac_prv.pem sed -e 's/[\&/]/\\&/g' -e 's/$/\\n    /' | tr -d '\n')/g" deployments/cf-aws-${CF_SIZE}.yml
  sed -i -e "s/UAAC_PUB_KEY/$(</tmp/uaac_pub.pem sed -e 's/[\&/]/\\&/g' -e 's/$/\\n    /' | tr -d '\n')/g" deployments/cf-aws-${CF_SIZE}.yml
  rm -f /tmp/uaac_prv.pem /tmp/uaac_pub.pem
fi

if [[ -n "$CF_SG_ALLOWS" ]]; then
  replacement_text=""
  for cidr in $(echo $CF_SG_ALLOWS | tr "," "\n"); do
    if [[ -n "$cidr" ]]; then
      replacement_text="${replacement_text}{\"protocol\":\"all\",\"destination\":\"${cidr}\"},"
    fi
  done
  if [[ -n "$replacement_text" ]]; then
    replacement_text=$(echo $replacement_text | sed 's/,$//')
    sed -i -e "s|^\(\s\+additional_security_group_rules:\s\+\).*|\1[$replacement_text]|" deployments/cf-aws-${CF_SIZE}.yml
  fi
fi

RELEASE=~/cf-release-${CF_RELEASE_VERSION}.tgz
test -e ${RELEASE} || wget -nv -O ${RELEASE} https://bosh.io/d/github.com/cloudfoundry/cf-release?v=${CF_RELEASE_VERSION}
bosh upload release ${RELEASE}

bosh deployment cf-aws-${CF_SIZE}
bosh prepare deployment || bosh prepare deployment  #Seems to always fail on the first run...

# We locally commit the changes to the repo, so that errant git checkouts don't
# cause havok
currentGitUser="$(git config user.name || /bin/true )"
currentGitEmail="$(git config user.email || /bin/true )"
if [[ "${currentGitUser}" == "" || "${currentGitEmail}" == "" ]]; then
  git config --global user.email "${USER}@${HOSTNAME}"
  git config --global user.name "${USER}"
  echo "blarg"
fi

gitDiff="$(git diff)"
if [[ ! "${gitDiff}" == "" ]]; then
  git commit -am 'commit of the local deployment configs'
fi

# Keep trying until there is a successful BOSH deploy.
for i in {0..2}
do bosh -n deploy
done

# Run smoke tests disabled - running into intermittent failures
#bosh run errand smoke_tests_runner

# Now deploy docker services if requested
if [[ $INSTALL_DOCKER == "true" ]]; then

  cd ~/workspace/deployments

  if [[ ! -d 'docker-services-boshworkspace' ]]; then
    git clone -b ${DOCKER_SERVICES_BOSHWORKSPACE_BRANCH} ${DOCKER_SERVICES_BOSHWORKSPACE_REPOSITORY} docker-services-boshworkspace
  fi

  echo "Update the docker-aws-vpc.yml with cf-boshworkspace parameters"
  /home/ubuntu/workspace/deployments/docker-services-boshworkspace/shell/populate-docker-aws-vpc ${CF_SIZE}
  dockerDeploymentManifest="/home/ubuntu/workspace/deployments/docker-services-boshworkspace/deployments/docker-aws-vpc.yml"
  /bin/sed -i \
    -e "s/SUBNET_ID/${DOCKER_SUBNET}/g" \
    -e "s/ENV_NAME/${ENV_NAME}/g" \
    -e "s/\(dns_servers:\).*/\1 [${CONSUL_MASTERS}]/" \
    -e "s/DOCKER_SG/${CF_SG}/g" \
    "${dockerDeploymentManifest}"

  cd ~/workspace/deployments/docker-services-boshworkspace
  bundle install
  bosh deployment docker-aws-vpc
  bosh prepare deployment

  #since we need to run an image that is downloaded
  #in a later step, this step will fail on the first try
  set +e
  bosh -n deploy
  set -e

  DOCKER_IP=$(bosh vms 2>&1| awk '/docker\/0/ { print $8 }')

  echo "#!/bin/sh" | sudo tee /etc/profile.d/docker.sh
  echo "export DOCKER_HOST=tcp://${DOCKER_IP}:4243" | sudo tee -a /etc/profile.d/docker.sh
  sudo chmod +x /etc/profile.d/docker.sh
  source /etc/profile.d/docker.sh

  #list all images, convert to JSON, get the container image and tag with JQ
  DOCKER_IMAGES=$(cat templates/docker-properties.yml | ruby -ryaml -rjson -e "print JSON.dump(YAML.load(ARGF))" |\
    jq -r ".properties.broker.services[].plans[].container | [.image, .tag] | @sh" | sed "s/' '/:/;s/'//g")
  #list all images in the jobs file
  DOCKER_JOBS_IMAGES=$(cat templates/docker-jobs.yml | ruby -ryaml -rjson -e "print JSON.dump(YAML.load(ARGF))" | jq -r ".jobs[].properties.containers[].image | @sh" | sed "s/'//g")

  #log in to quay when the username is provided
  if [[ -n "$QUAY_USERNAME" ]]; then
    docker -H "tcp://${DOCKER_IP}:4243" login -u $QUAY_USERNAME -p $QUAY_PASS -e test@test quay.io
  fi

  #pull all public images. private ones will fail when not logged in
  set +e
  for image in $DOCKER_IMAGES $DOCKER_JOBS_IMAGES; do
    docker -H "tcp://${DOCKER_IP}:4243" pull $image
  done
  set -e

  #now the deployment that will make persistent 
  #containers working
  bosh -n deploy
fi

if [[ $INSTALL_LOGSEARCH == "true" ]]; then
  sudo apt-get install python-jinja2 -y

  cd ~/workspace/deployments

  if [[ ! -d 'logsearch-workspace' ]]; then
    git clone -b ${LOGSEARCH_WORKSPACE_BRANCH} ${LOGSEARCH_WORKSPACE_REPOSITORY} logsearch-workspace
  fi

  export X_ADMIN_PASS="$CF_ADMIN_PASS"
  export X_AWS_SUBNET="$LS_SUBNET1"
  export X_AWS_SG="$CF_SG"
  export X_AWS_AZ="$LS_SUBNET_AZ"
  export X_CF_DOMAIN="$CF_DOMAIN"
  export X_CLIENT_PASS="$CF_CLIENT_PASS"
  export X_DIRECTOR_UUID="$DIRECTOR_UUID"

  cd "$HOME/workspace/deployments/logsearch-workspace"
  mkdir -p releases
  if [[ ! -d "releases/logsearch-for-cloudfoundry" ]]; then
    git clone https://github.com/logsearch/logsearch-for-cloudfoundry.git releases/logsearch-for-cloudfoundry
  fi

  cd releases/logsearch-for-cloudfoundry
  bosh upload release releases/logsearch-for-cloudfoundry/logsearch-for-cloudfoundry-7.yml
  cd ../..

  bosh upload release https://bosh.io/d/github.com/logsearch/logsearch-boshrelease?v=23.0.0

  python generate_template.py manifest-aws.yml.j2

  bosh -d manifest.yml -n deploy
  bosh -d manifest.yml -n run errand push-kibana
fi

echo "Provision script completed..."
exit 0

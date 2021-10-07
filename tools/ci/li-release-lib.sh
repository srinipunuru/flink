#!/usr/bin/env bash
################################################################################
#  Licensed to the Apache Software Foundation (ASF) under one
#  or more contributor license agreements.  See the NOTICE file
#  distributed with this work for additional information
#  regarding copyright ownership.  The ASF licenses this file
#  to you under the Apache License, Version 2.0 (the
#  "License"); you may not use this file except in compliance
#  with the License.  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
# limitations under the License.
################################################################################

#
# This file contains tooling for compiling Flink
#

HERE="`dirname \"$0\"`"             # relative
HERE="`( cd \"$HERE\" && pwd )`"    # absolutized and normalized
if [ -z "$HERE" ] ; then
    exit 1  # fail
fi
CI_DIR="$HERE/../ci"
MVN_CLEAN_COMPILE_OUT="/tmp/clean_compile.out"

# Deploy into this directory, to run license checks on all jars staged for deployment.
# This helps us ensure that ALL artifacts we deploy to maven central adhere to our license conditions.
MVN_VALIDATION_DIR="/tmp/flink-validation-deployment"

# source required ci scripts
source "${CI_DIR}/stage.sh"
source "${CI_DIR}/shade.sh"
source "${CI_DIR}/maven-utils.sh"

echo "Maven version:"
run_mvn -version

echo "=============================================================================="
echo "Compiling Flink"
echo "=============================================================================="

EXIT_CODE=0

if [ -z "$JFROG_USERNAME_ENV" ]; then
  echo "ERROR: jfrog username isn't provided"
  exit 1
fi
if [ -z "$JFROG_PASSWORD_ENV" ]; then
  echo "ERROR: jfrog password isn't provided"
  exit 1
  echo
fi

if [ -z "$RELEASE_VERSION_OVERRIDE" ]; then
  echo "Generating build version"
  # we first get calcite's version. We expect that this will be updated if we sync with Apache Calcite
  OPEN_SOURCE_VERSION=$(grep -A1 "flink-parent</artifactId>" pom.xml  | grep  -E "<version>(.*)</version>" | cut -d'>' -f2 | cut -d'<' -f1 | sed  's/[^0-9.]*//g')
  OPEN_SOURCE_MAJ_VERSION=$(cut -d'.' -f1 <<< $OPEN_SOURCE_VERSION)
  OPEN_SOURCE_MIN_VERSION=$(cut -d'.' -f2 <<< $OPEN_SOURCE_VERSION)
  LI_MAJ_VERSION=$(printf "%d%02d\n" $OPEN_SOURCE_MAJ_VERSION $OPEN_SOURCE_MIN_VERSION)
  
  # next, we get the hash of the latest commit that tracks Apache Calcite. We expect that this will be updated if we sync with Apache Calcite
  #APACHE_CALCITE_LAST_COMMIT_HASH=$(grep -E "<calciteCommitHash>(.*)</calciteCommitHash>" pom.xml | cut -d'>' -f2 | cut -d'<' -f1)
  # next, we count the number of commits we have made on top of Apache Calcite since the last sync.
  #GIT_COMMIT_COUNT=$(git rev-list --count $APACHE_CALCITE_LAST_COMMIT_HASH..HEAD)
  # next, we create an internal version. 100 is an arbitrary seed
  # now we can construct a build version
  if [ -z "$DEV_VERSION" ]; then
    BUILD_VERSION="${LI_MAJ_VERSION}.${LI_MIN_VERSION}"
  else
    BUILD_VERSION="${LI_MAJ_VERSION}.${LI_MIN_VERSION}.${DEV_VERSION}"
  fi
  echo "Current build version: ${BUILD_VERSION}"
else 
  BUILD_VERSION=$RELEASE_VERSION_OVERRIDE
  echo "Current build version: ${BUILD_VERSION}"
fi


run_mvn clean 
# override Maven coordinates to LinkedIn version
# This line will change .pom files automatically. If it runs in local, it's necessary to manually revert all the changes.
run_mvn versions:set -DnewVersion=$BUILD_VERSION -DoldVersion=* -DgroupId=org.apache.flink -DartifactId=* 
# Need to revert the override for dummy module force-shading 
run_mvn versions:set -DnewVersion=1.12-SNAPSHOT -DoldVersion=* -DgroupId=org.apache.flink -DartifactId=force-shading 
run_mvn deploy -DaltDeploymentRepository=validation_repository::default::file:$MVN_VALIDATION_DIR $MAVEN_OPTS -Dflink.convergence.phase=install -Djfrog.exec.publishArtifacts=true -Djfrog.publisher.password=$JFROG_PASSWORD_ENV -Djfrog.publisher.username=$JFROG_USERNAME_ENV -Pcheck-convergence -Dflink.forkCount=2 \
    -Dflink.forkCountTestPackage=2 -Dmaven.javadoc.skip=true -U -DskipTests | tee $MVN_CLEAN_COMPILE_OUT

EXIT_CODE=${PIPESTATUS[0]}

if [ $EXIT_CODE != 0 ]; then
    echo "=============================================================================="
    echo "Compiling Flink failed."
    echo "=============================================================================="

    grep "0 Unknown Licenses" target/rat.txt > /dev/null

    if [ $? != 0 ]; then
        echo "License header check failure detected. Printing first 50 lines for convenience:"
        head -n 50 target/rat.txt
    fi

    exit $EXIT_CODE
fi
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


function getBuildVersion {
if [ -z "$RELEASE_VERSION_OVERRIDE" ]; then
  # we first get calcite's version. We expect that this will be updated if we sync with Apache Calcite
  OPEN_SOURCE_VERSION=$(grep -A1 "flink-parent</artifactId>" pom.xml  | grep  -E "<version>(.*)</version>" | cut -d'>' -f2 | cut -d'<' -f1 | sed  's/[^0-9.]*//g')
  OPEN_SOURCE_MAJ_VERSION=$(cut -d'.' -f1 <<< $OPEN_SOURCE_VERSION)
  OPEN_SOURCE_MIN_VERSION=$(cut -d'.' -f2 <<< $OPEN_SOURCE_VERSION)
  LI_MAJ_VERSION=$(printf "%d%02d%02d\n" $OPEN_SOURCE_MAJ_VERSION $OPEN_SOURCE_MIN_VERSION $BACKWARD_COMPATIBILITY_INDEX_ENV)
  
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
else 
  BUILD_VERSION=$RELEASE_VERSION_OVERRIDE
fi
echo $BUILD_VERSION
}
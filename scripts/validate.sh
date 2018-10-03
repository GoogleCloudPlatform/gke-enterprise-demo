#!/bin/bash

# Copyright 2018 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# "---------------------------------------------------------"
# "-                                                       -"
# "-  Validate the ElasticSearch Cluster on GKE via APIs   -"
# "-                                                       -"
# "./expose.sh needs to run before the script runs         -"
# " expose.sh ports forward the local TCP 9200 traffic to pyrios in the cloud -"
# "---------------------------------------------------------"

set -o errexit
set -o nounset
set -o pipefail

# make sure curl is installed
command -v curl  >/dev/null 2>&1 || { \
 echo >&2 "I require curl but it's not installed.  Aborting."; exit 1; }
# make sure jq is installed
command -v jq  >/dev/null 2>&1 || { \
 echo >&2 "I require jq but it's not installed.  Aborting."; exit 1; }

fail() {
  echo "ERROR: ${*}"
  exit 2
}

# Validate ES version
EXPECTED_ES_VERSION=6.2.4
ES_VERSION=$(curl -s http://localhost:9200/ | jq -r '.version.number')
if [[ "$ES_VERSION" == "$EXPECTED_ES_VERSION" ]]
then
 echo "Elasticsearch version matched"
else
 fail "Elasticsearch version mismatched"
fi

sleep 1

# Validate ES status
EXPECTED_STATUS=green
ES_STATUS=$(curl -s 'http://localhost:9200/_cluster/health' | jq -r '.status')
if  [[ "$ES_STATUS" == "$EXPECTED_STATUS" ]]; then
  echo "Elasticsearch cluster status is green"
else
  fail "Please check the Elasticsearch cluster status as it is NOT ${EXPECTED_STATUS}"
fi

sleep 1
# Validate if the shakespare index exists and has the right number of shards
EXPECTED_NO_OF_SHARDS=5
NO_OF_SHARDS=$(curl -s -X GET "localhost:9200/shakespeare" | jq -r '.shakespeare.settings.index.number_of_shards // empty')
if [[ -z "$NO_OF_SHARDS" ]]; then
     fail "Please check if shakespeare data has been loaded"
fi
if  [[ "$NO_OF_SHARDS" -eq "$EXPECTED_NO_OF_SHARDS" ]]; then
    echo "Shakespeare data has the expected number of shards"
else
    fail "Please check if shakespeare data has been loaded"
fi

sleep 1

# https://www.elastic.co/guide/en/elasticsearch/reference/6.2/query-dsl.html
# Elasticsearch provides a full Query DSL (Domain Specific Language) based on JSON to define queries

# Validate if the number of hists matches with the search
# https://www.elastic.co/guide/en/elasticsearch/reference/6.2/query-dsl-match-all-query.html
EXPECTED_NO_OF_HITS=5
NO_OF_HITS=$(curl -s -X GET "localhost:9200/shakespeare/_search" -H 'Content-Type: application/json' -d'
{
  "query": { "match_all": {} },
  "from": 10,
  "size": 5
}' | jq -r '.hits.hits |length')
if  [[ "$NO_OF_HITS" -eq "$EXPECTED_NO_OF_HITS" ]]; then
    echo "Shakespeare match_all query has the expected numbers of hits"
else
    fail "Please check why the query has the wrong numbers of hits"
fi

sleep 1

# https://www.elastic.co/guide/en/elasticsearch/reference/6.2/query-dsl-match-query.html
EXPECTED_NO_OF_HITS=10
NO_OF_HITS=$(curl -s -X GET "localhost:9200/shakespeare/_search" -H 'Content-Type: application/json' -d'
{
    "query": {
    "match" : {
        "speaker" : "LEONATO"
        }
    }
}' | jq -r '.hits.hits |length')
if  [[ "$NO_OF_HITS" -eq "$EXPECTED_NO_OF_HITS" ]]; then
    echo "Shakespeare match query on speaker LEONATO has the expected numbers of hits"
else
    fail "Please check why the query has the wrong numbers of hits"
fi


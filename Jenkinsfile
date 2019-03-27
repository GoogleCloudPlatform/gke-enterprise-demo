#!/usr/bin/env groovy
/*
Copyright 2018 Google LLC

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    https://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

*/

// The declarative agent is defined in yaml.  It was previously possible to
// define containerTemplate but that has been deprecated in favor of the yaml
// format
// Reference: https://github.com/jenkinsci/kubernetes-plugin
// set up pod label and GOOGLE_APPLICATION_CREDENTIALS (for Terraform)
def label = "k8s-infra"
def containerName = "k8s-node"
def GOOGLE_APPLICATION_CREDENTIALS    = '/home/jenkins/dev/jenkins-deploy-dev-infra.json'

podTemplate(label: label, yaml: """
apiVersion: v1
kind: Pod
metadata:
  labels:
    jenkins: build-node
spec:
  containers:
  - name: ${containerName}
    image: gcr.io/pso-helmsman-cicd/jenkins-k8s-node:${env.CONTAINER_VERSION}
    command: ['cat']
    tty: true
    volumeMounts:
    # Mount the dev service account key
    - name: dev-key
      mountPath: /home/jenkins/dev
  volumes:
  # Create a volume that contains the dev json key that was saved as a secret
  - name: dev-key
    secret:
      secretName: jenkins-deploy-dev-infra
"""
 ) {
   node(label) {
     try {
       // Options covers all other job properties or wrapper functions that apply to entire Pipeline.
       properties([disableConcurrentBuilds()])
       // set env variable GOOGLE_APPLICATION_CREDENTIALS for Terraform
       env.GOOGLE_APPLICATION_CREDENTIALS=GOOGLE_APPLICATION_CREDENTIALS

       stage('Setup') {
         container(containerName) {
           // Setup gcloud service account access
           sh "gcloud auth activate-service-account --key-file=${GOOGLE_APPLICATION_CREDENTIALS}"
           sh "gcloud config set compute/zone ${env.ZONE}"
           sh "gcloud config set core/project ${env.PROJECT_ID}"
           sh "gcloud config set compute/region ${env.REGION}"

           sh 'echo "credential_file=${GOOGLE_APPLICATION_CREDENTIALS}" > /home/jenkins/.bigqueryrc'
         }
       }

       stage('Linting') {
         container(containerName) {
           // checkout the source code
           checkout scm
           // setup the cluster k8s file for linting
           sh "make configure"
           // This will run all of our source code linting
           sh "make lint"
         }
       }

       stage('Terraform') {
         container(containerName) {
           // This will run terraform init and terraform apply
           sh "make terraform"
         }
       }

       stage('Create') {
         container(containerName) {
           // setup the cluster k8s file
           sh "make configure"
           // configure docker so that bazel can upload files
           sh "gcloud auth configure-docker --quiet"
           // create es cluster and run bazel
           // we set the repo to use since the cluster is running in a different project
           sh "CONTAINER_REPO=gcr.io/pso-helmsman-cicd-infra make create"
         }
       }

       stage('Load Data') {
         container(containerName) {
           // wait till the pyrios deployment is up
           sh "make wait-on-pyrios"
           // This will port-forward to the pyrios pod on port 9200
           sh "make expose"
           // This will use the local port 9200 to load data into Elasticsearch
           sh "make load"
         }
       }

       stage('Test') {
         container(containerName) {
           // validate the cluster
           sh "make validate"
         }
      }
    }
    catch (err) {
      // if any exception occurs, mark the build as failed
      // and display a detailed message on the Jenkins console output
      currentBuild.result = 'FAILURE'
      echo "FAILURE caught echo ${err}"
      throw err
    }
    finally {
      stage('Teardown') {
        container(containerName) {
          // This will create k8s.env which contains context names
          sh "make configure"
          // This will destroy all of the resources created in this demo
          sh "make teardown"
        }
      }
    }
  }
}

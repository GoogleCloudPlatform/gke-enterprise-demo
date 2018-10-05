#!/usr/bin/env bash

case $DEPLOY_ENV in
	dev)
		echo "gke_pso-helmsman-shared-demo-dev_us-west1-b_cloud-cluster"
		;;
	staging)
		echo "gke_pso-helmsman-cicd-infra_us-west1-b_cloud-cluster"	
		;;
	*)
		exit 1
esac

#!/usr/bin/env bash

case $DEPLOY_ENV in
	dev)
		echo "gcr.io/pso-helmsman-shared-demo-dev"
		;;
	staging)
		echo "gcr.io/pso-helmsman-cicd-infra"	
		;;
	*)
		exit 1
esac

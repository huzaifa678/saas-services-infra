#!/bin/bash
set -ex
/etc/eks/bootstrap.sh ${cluster_name} \
  --b64-cluster-ca ${cluster_ca} \
  --apiserver-endpoint ${cluster_endpoint} \
  --dns-cluster-ip $(echo ${cidr} | sed 's/0\/.*$/10/')

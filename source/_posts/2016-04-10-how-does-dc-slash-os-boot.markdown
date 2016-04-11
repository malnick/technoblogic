---
layout: post
title: "How Does DC/OS Boot?"
date: 2016-04-10 14:08:53 -0700
comments: true
categories: 
---
It's an operating system right? What happens when you start DC/OS? 

DC/OS is composed of many services, acting across the cluster, to bring the entire state of the cluster into an 'up' state. 

## Installation
Genesis begins with the installer. The installer runs in three stages, each with their own sub-stages:

1. Preflight
  1. Install DC/OS Prerequists (only on CentOS 7x):
    - Install packages:
      - docker
      - wget
      - git
      - unzip
      - curl
      - xz
      - ipsec
    - Add the `nogroup` group
    - Configure docker for overlay filesystem
    - If running and enforcing, disable selinux
  1. Run preflight checks to ensure prerequists are correctly provisioned and configured:
    - Check for packages: 
      - curl
      - bash
      - ping
      - tar
      - xz 
      - unzip
      - systemd-notify
    - Ensure ports for DC/OS are available:
      - 80 Mesos UI
      - 53 Mesos DNS
      - 15055 History Service
      - 5050 Mesos Master
      - 2181 Zookeeper
      - 8080 Marathon
      - 3888 Zookeeper
      - 8181 Exhibitor
      - 8123 Mesos DNS
    - Ensure Docker is not using devicemapper in loopback as storage driver
    - Ensure there is not pre existing DC/OS cluster installed

1. Install DC/OS
  1. Setup working directories
    - /opt/mesosphere
    - Install DC/OS roles: /etc/mesosphere/roles/$role
    - Configure and start DC/OS services
 

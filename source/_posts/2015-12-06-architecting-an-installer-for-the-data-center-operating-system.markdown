---
layout: post
title: "Architecting An Installer for the Data Center Operating System"
date: 2015-12-06 08:48:28 -0800
comments: true
categories: 
---
1. What is the install challenge
2. How we started
3. Current iteration
3. How we are going to improve it later
4. Close

Mesosphere's Data Center Operating System (DCOS) is a distributed cluster manager and resource scheduler that enables companies to execute their application with high parallelization and availability. The DCOS ecosystem consists of many open source and proprietary tools to manage executing client applications in the cluster. The core utilities are Apache Mesos, Mesos DNS, Mesosphere's Marathon, Nginx, Apache Zookeeper and Zookeeper Exhibitor (FOSS from Netflix). The production-read version of DCOS runs 3-5 Apache Mesos Masters with 'n' number of Apache Mesos Agents. 

Properly configuring and installing this suite of tools to large on-premise deployments poses many challenges:

1. Bootstrapping the cluster for high availability 
3. Bootstrapping the cluster from a single target "bootstrapping" host
4. Scoping the configuration available to Mesosphere clients
  1. Master discovery configuration
  2. Exhibitor configuration
5. Continuous integration tests on the actual software that manages DCOS installation

Because of the complexity with bootstrapping a highly available cluster from scratch we have to present the end-user with a lot of implementation details and configuration which is often times confusing and sets a barrier to entry to using DCOS. 

Traditionally, you can ship software to a node using well-known package managers (Aptitude or Yum). However, DCOS is designed to run on **any** linux distribution, which means we'd have to support all the package management repos our potential customers require: Yum, Aptitude, Pacman, Zypper, etc. Furthermore, since this is a distributed cluster, we have to seed each deployment package with site-specific configuration for each part of the DCOS system. This means the package manager would have to include some way for us to configure cluster wide settings for things like Zookeepers' zoo.cfg file (managed by Exhibitor), Mesos DNS configuration, and other distributed utilities.

In the end, we would have to configure every node in the cluster with our package repo and this site-specific configuration before the DCOS package actually installs. We could use configuration management for this, but in that case we'd also have to write Puppet modules, Chef cookbooks, Ansible playbooks and Salt code to name a few, to ensure we cover all the possible customer requirements for installing DCOS at a given site. 

This locks us in to managing a package repo per customer (not to mention tests on each built package system) and a given installation method using configuration management. Let's not even begin to talk about the complexity of maintaining those configuration management codebases across multiple versions of the configuration management suite (in other words, customer A is running Puppet 3x, customer B is running Puppet 2x and customer C is running Puppet 4x - good luck keeping that complicated module cross functional across all versions previous and future - and that's for just a single configuration management suite).

In the end, we opted to design an installer that any customer could run, regardless of configuration management implementation or underlying operating system package managers. This installer can easily integrate with existing configuration management systems or install the cluster via SSH to the distributed nodes. It can also walk customers through the often complicated process of configuring the underlying system before it installs with a user-friendly web UI.

## How We Started
Our first try at the on-premise installer was a CLI tool that automated configuring and building a bootstrap tarball. 

## Our Current Iteration

## Future Improvements 







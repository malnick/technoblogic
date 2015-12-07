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
Our first try at the on-premise installer was a CLI tool that automated configuring and building a bootstrap tarball. It used a JSON configuration file that had some drawbacks. Primarily, we use only string-based variables in our configuration file templates, so we required anything other than strings (such as arrays) in the JSON config, had to be strings:

```json
"variable": "[\"var1\",\"var2\"]"
```

This was obviously less than ideal.

Secondly, the CLI utility required the end-user to have some way to distribute the tarball it created. This left a lot up to the end-user, and was a point of contention. 

Lastly, the end user had a lot of configurated exposed to her that was often confusing. The biggest hurdle was sometimes explaining what Exhibitor was, how to configure it, and in some cases why it needed its own Zookeeper quorum to bootstrap the DCOS quorom. 

All of these issues pointed towards a major overhaul of this installation process.  

## Our Current Iteration
#### User Interface
On the outset, we wanted to create an installer that had a user interface. This UI would allow us to walk the user through configuring the DCOS cluster. It would also allow us to quickly copy and paste configuration into the UI, and abstract all the complexity of this process to a clean interface.  

#### Internally Bootstrap Exhibitor
We also wanted to remove the Exhibitor configuration from the end-user, getting rid of this confusing configuration piece would lower the barrier to entry and solve many of our support calls. Under the hood, we achieve this by writing our own static ensamble for bootstrapping exhibitor. This new backend to exhibitor allowed us to pass it our static master list to the backend, and it writes this, regardless of cluster state, to the zoo.cfg. 

#### SSH Deploy 
This new installer would also have a deploy option. The deploy option would leverage SSH on the backend to execute preflight checks on the target hosts in the cluster; install the DCOS tarball to the machines; and execute post-flight checks on the target hosts to enure the cluster was in a working state. 

#### YAML Configuration File
This new installer levareages a YAML configuration file. The UI walks the user through building this YAML file but the beauty is that we can ship pre-built YAML files with in-line comments. JSON doesn't allow us to put comments in the file, and with that option available we can make more clear what each configuration parameter does without having the end-user touch the UI.

#### Configuration Management Integration
Our previous installer shipped around the installer script, which would pull the tarball from the configuration machine. In this way, it was partially on its way to integrating with configuration management. However, the previous installer did not ship a server to serve that tarball. It was up to the end-user to configure an NGINX, Apache or other server that would allow the script to pull down the tarball from the host machine.

For many systems administrators this was fine, however, for many it was just another barrier to entry. To simplify this process we're now shipping a built in server and an option to execute the CLI mode of the installer with ```--bootstrap_url```. 

```--bootstrap_url``` exposes a URL on the installer host: ```http://$INSTALLER_IP:9000/bootstrap```

With this feature, you can expose the bootstrap URL on the installer host and write a very simple Puppet module, Chef cookbook or Ansible playbook to pull the tarball, extract it to the filesystem and create the required symlinks. This is a far more simple option to management of your configuration management code than building all the current and possible future config files for DCOS. Now it's just three unix-level operations. 

## Future Improvements 







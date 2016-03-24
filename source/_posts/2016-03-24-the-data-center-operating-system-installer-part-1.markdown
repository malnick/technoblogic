---
layout: post
title: "Building an Installer for the Data Center Operating System" 
date: 2016-03-24 08:54:43 -0700
comments: true
categories: 
---
The Data Center Operating System (DCOS) is a distributed, highly available task scheduler built by [Mesosphere](http://mesosphere.io). It uses a number of open and close source projects to make running and administering Apache Mesos as seamless and simple as possible. The DCOS runs at scale (we have customers running production deployments of 50,000 nodes), across thousands of machines. This post covers challenges, design and an overview of the final GUI installer we built to install an operating system for the data center.  
<!--more-->
## Installation Challenge
Installation of the DCOS has always been a tricky endeavor. Each cluster has site-specific customizations which must be translated into configuration files for various pieces of the DCOS ecosystem. These configuration files need to be compiled into a shippable package and those packages need to be installed on tens of thousands of hosts.

For lack of a better meme,

  "One does not simply upgrade the Data Center Operating System".

When you install the DCOS, you need to install a specific role on each host depending on if that host is a master, a public agent or a private agent, or just simply an agent.

Sure this whole thing would be simple with Ansible, Puppet or Chef. But you can't ship enterprise software and pigeon hole your paying customers into using one of these systems over the other. We are working on building a module, cookbook and playbook for these deployments, but our UI installer needs to ship DCOS to a cluster even if they do not exist.  

## SSH Based Installation
Mesosphere is a Python shop, being able to leverage an existing library to do the SSHing would be fantastic. We vetted the following libraries:

1. [Ansible SSH Library](https://github.com/ansible/ansible)
2. [Salt SSH Library](https://docs.saltstack.com/en/latest/topics/ssh/)
3. [Paramiko](http://www.paramiko.org/)
4. [Parallel SSH](https://pypi.python.org/pypi/parallel-ssh)
5. [Async SSH](http://asyncssh.readthedocs.org/en/latest/)
6. Subprocess (shelling out to SSH)

All of these SSH libraries did not work for us. The library was either not compatible with Python 3x or had licensing restrictions. This left us with concurrent subprocess calls to the SSH executable.

 This wasn't something that we were particularly fond of, because if you've ever seen how much code it takes to make this a viable option (just look at [Ansible's SSH executor class](https://github.com/ansible/ansible/blob/stable-2.0.0.1/lib/ansible/executor/task_executor.py#L49) you can understand it's not trivial.

Also, our final product would be a web-based GUI with a CLI utility. The library we chose must be compatible with asyncio, which will be the web framework of the final HTTP API.

## YAML Based Configuration File Format
Previous versions of the DCOS shipped what our customers know as `dcos_generate_config.sh`. This bash script is in fact a self extracting docker container which runs our configuration generation library, this is what builds the DCOS configuration files per input in the config.yaml.

This used to be in JSON format, but we moved this to a YAML format which is more user-friendly. In `DCOS v1.5` we shipped the first version of this new configuration file format. In `DCOS v1.6` we made a modification to the format of this file to flatten the configuration parameters, so there are no nested dictionaries, simplifying the process further.

## The User Interface
Finally, we built a completely new web-based graphical user interface. Previously, DCOS end-users relied on our documentation to get the configuration parameters in their config.yaml correct. These parameters were often a source of constant documentation updates and inputing them was error prone. The new GUI gives our end users constant feedback about the state of their configuration, and we hope to build this experience to make it even more dynamic in the future:

<SS WELCOME>

The configuration page gives you robust error information:

<SS CONFIGURE>

The preflight installs cluster host prerequisites for you:

<SS WARNING>

The preflight process gives you real-time preflight feedback across all cluster hosts:

<SS PREFLIGHT ERROR OUTPUT>

All stages give you real-time status bars:

<SS DEPLOY STATUS BARS>

The postflight ensures the deployment process was successful, and your cluster is ready for use:

<SS POSTFLIGHT RUNNING>
<SS SUCCESS>

You can get a detailed log of each stage at anytime, and send this to our support team if you run into issues:

<SS LOGS>

## That's It! 
And that's all there is to it, your one-stop shop to deploying your highly available, fault tolerant, enterprise-scale Data Center Operating System. We have many improvements and features we'll be adding to our new installer in the very near future, please stay up to date and watch this blog for more great additions to our installer.  

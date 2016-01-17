---
layout: post
title: "How to deploy highly scalable systems over SSH"
date: 2016-01-17 13:28:26 -0800
comments: true
categories: 
---
## Background
The Secure Shell (SSH) is a well known utility for securely logging into remote hosts. It's also been widely used as a secure remote execution framework. Today, well known tools in the area of configuration management leverage SSH to safely manage state across thousands of hosts. Many systems administrators reach for SSH when they have to automate execution of scripts across distributed hosts, and others use it every day to log into remote systems on cloud platforms. 
<!-- more -->
At [Mesosphere](https://mesosphere.com/), we're building the next generation of highly available, distributed task schedulers. Our core product is the Data Center Operating System (DCOS). DCOS is a mixture of many open and closed source products, primarily among them Apache [Mesos](http://mesos.apache.org/) and [Zookeeper](https://zookeeper.apache.org/). 

The DCOS runs at scale (we have customers running production deployments of 50,000 nodes), across thousands of machines. It's primary goal is to abstract away the mundane and technically challenging process of deploying highly available applications. The DCOS consists of masters and agents. In a typical production deployment you have 3 to 5 masters and 'n' number of agents that comprise the core resources of your cluster.

## Installation Challenge
The DCOS is a highly stable, highly available system. It can withstand network partitions and master host failures. However, installation of the DCOS has always been a tricky endeavor. Each cluster has site-specific customizations which must be translated into configuration files for various pieces of the DCOS ecosystem. These configuration files need to be compiled into a shippable package and those packages need to be installed on tens of thousands of hosts.

This configuration generation process differs based on locality: is the deployment in AWS or another cloud platform where we might not know master IP addresses before deployment? Is the deployment behind a VRRP or other master-host load balancer such as an ELB? Is the customer using zookeeper, S3 or a shared file system for [Exhibitor](https://github.com/Netflix/exhibitor)'s bootstrapping process? 

## SSH Deployment
The first version of the DCOS installer consisted of a utility that read in a JSON configuration file which declared site-specific customizations, and generated a bootstrap and associated packages. However, the end-user was left to develop a way to ship those components or make them available to our install script, which itself had to be shipped around to hosts and somehow executed. 

It became apparent that we needed a way to automate the entire installation process across the cluster. We could not use traditional tools to do this. Where in a previous life I could reach for Puppet, Chef or Ansible to do this distributed dirty work, we could not pigeon hole customers into deploying one of these systems. We had to stick to system utilities and embody a "leave no trace" policy - the only artifact the installer should leave is a working DCOS master or agent installation on each host. 

### Design Concept
Mesosphere is a Python shop, being able to leverage an existing library to do the SSHing would be fantastic. We vetted the following libraries:

1. [Ansible SSH Library](https://github.com/ansible/ansible)
2. [Salt SSH Library](https://docs.saltstack.com/en/latest/topics/ssh/)
3. [Paramiko](http://www.paramiko.org/)
4. [Parallel SSH](https://pypi.python.org/pypi/parallel-ssh)
5. [Async SSH](http://asyncssh.readthedocs.org/en/latest/)
6. Subprocess (shelling out to SSH)

Unfortunately, every library we tried we were unable to implement. The library was either not compatible with Python 3x or had licensing restrictions. This left us with concurrent subprocess calls to the SSH executable. This wasn't something that we were particularly fond of, because if you've ever seen how much code it takes to make this a viable option (just look at Ansible's SSH runner class) you can understand it's not trivial. 

Also, our final product would be a web-based GUI with a CLI utility. The library we chose must be compatible with asyncio, which will be the web framework of the final HTTP API. Finally, the entire library had to be bullet proof. 
 
### Lessons
#### Security Restrictions
##### RequireTTY
```/etc/sudoers``` has a default policy on most systems to ```requiretty``` if you're executing ```sudo```. That means, if you ```ssh user@host``` and don't attach a TTY to your session, you'll be disallowed from from executing ```sudo installmyapp.sh``` even if user is allowed in sudoers. 

The fix for this is to implement your ssh session as ```ssh -t user@host```. This tells the remote host to attach a PTY to to session. At the most basic level you're telling the host that you're an interactive shell. However, since we're executing SSH in a subprocess, that's actually not true. 

To have SSH allocate a PTY to the subprocess you can execute ```ssh -tt user@host```, now we have two allocated PTY's, one on each end of the session. This works great if you're executing SSH on a host machine, but of course our installer is running as a docker container. If you execute a SSH session from the docker container and you didn't execute the container in interactive mode and allocate a PTY with ```docker -it``` you won't be able to read in the STDOUT and STDERR from the remote machine. 

The final fix is the allocate PTY on your docker container and both ends of the SSH session: 

***SSH Binary in Docker***:*PTY* -> ***Docker Container***:*PTY* -> ***Docker Host***:*PTY* -> ***Remote Host SSH Binary***:*PTY*

##### Users
Everyone one expects your SSH deployer to use the user they currently are. This isn't easy to achieve if you're application is in Docker. You must run a privileged container and allow it to access these parts of the host system. That's not always desired either.
#### Logging
##### Annoying Warnings

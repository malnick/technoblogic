---
layout: post
title: "Building an Installer for the Data Center Operating System"
date: 2016-01-31 08:51:38 -0800
comments: true
categories: 
---
The Data Center Operating System (DCOS) is a distributed, highly available task scheduler built by [Mesosphere](http://mesosphere.io). It uses a number of open and close source projects to make running and administering Apache Mesos as seemless and simple as possible. The DCOS runs at scale (we have customers running production deployments of 50,000 nodes), across thousands of machines. It's primary goal is to abstract away the mundane and technically challenging process of deploying highly available applications. The DCOS consists of masters and agents. In a typical production deployment you have 3 to 5 masters and 'n' number of agents that comprise the core resources of your cluster.

## Installation Challenge
Installation of the DCOS has always been a tricky endeavor. Each cluster has site-specific customizations which must be translated into configuration files for various pieces of the DCOS ecosystem. These configuration files need to be compiled into a shippable package and those packages need to be installed on tens of thousands of hosts.

This configuration generation process differs based on locality: is the deployment in AWS or another cloud platform where we might not know master IP addresses before deployment? Is the deployment behind a VRRP or other master-host load balancer such as an ELB? Is the customer using zookeeper, S3 or a shared file system for [Exhibitor](https://github.com/Netflix/exhibitor)'s bootstrapping process?

The technical challenges of installation don't stop with configuration generation either. Beyond that, simply ensuring that DCOS is shipped and properly configured on each host poses even more obsticles. We can't ship the DCOS as an RPM, Yum or Apt package as this would cause chaos during upgrades. Not only do we have a concept of upgrading the underlying DCOS software but we also have a concept of upgrading the frameworks, stateless and stateful, which run on top of it. 

For lack of a better meme, 

  "One does not simply upgrade the Data Center Operating System".

When you install the DCOS, you need to install a specific role on each host depending on if that host is a master, a public agent or a private agent, or just simply an agent. 

Sure this whole thing would be simple with Ansible, Puppet or Chef. But you can't ship enterprise software and pigeon hole your paying customers into using one of these systems over the other. Furthermore, this is the DCOS - it should be installable without involving complicated configuration management systems. We wanted to build a tool that you could run, access in a UI and deploy a cluster with minimal end-user thinking.

## In the Beginning 
The first version of the DCOS installer consisted of a utility that read in a JSON configuration file which declared site-specific customizations, and generated a bootstrap and associated packages. However, the end-user was left to develop a way to ship those components or make them available to our install script, which itself had to be shipped around to hosts and somehow executed.

Furthermore, because of the way we process this configuration file to generate the site-specific configuration files we required that all things in this JSON file were strings. For example, even though we processed an array of IPv4 addresses for the ```resolvers``` setting, you had to enter in that array as a string:

```json
"resolvers": "[\"8.8.8.8\", \"8.8.4.4\"]"
```

Obviously this wasn't an ideal end-user experience. It was even harder to get the wording right in the docs so people understood what we meant. 

The first 4 versions of the installer were designed around building the configuration for the DCOS. The artifacts from running ```dcos_generate_config.sh``` would output the entire cluster cluster configuration as packages and a bootstrap tar ball plus a handy ```install_dcos.sh``` which pointed at the value for the ```bootstrap_url``` parameter in your config.json. You could ship this script to each host in your infrastructure, and run ```./install_dcos.sh $ROLE``` (where $ROLE is master, slave or slave_public) and it would download these artifacts and install the DCOS.

This was slick, but still required the end-user do a lot of manual work. She had to setup a nginx or other web server to serve the artifacts from the host in the ```bootstrap_url```. She had to manually move the install script to each host and run run it. She also, per host, had to manually run the preflight. 

It became apparent that we needed a way to automate the entire installation process across the cluster. Where in a previous life I could reach for Puppet, Chef or Ansible to do this distributed dirty work, we could not pigeon hole customers into deploying one of these systems. We had to stick to system utilities and embody a "leave no trace" policy - the only artifact the installer should leave is a working DCOS master or agent installation on each host. 

Furthermore, our automated installer should be user-friendly, easy to understand and run those preflight and postflight checks in a single place (like a web UI!).

## SSH Library Design Concept
Mesosphere is a Python shop, being able to leverage an existing library to do the SSHing would be fantastic. We vetted the following libraries:

1. [Ansible SSH Library](https://github.com/ansible/ansible)
2. [Salt SSH Library](https://docs.saltstack.com/en/latest/topics/ssh/)
3. [Paramiko](http://www.paramiko.org/)
4. [Parallel SSH](https://pypi.python.org/pypi/parallel-ssh)
5. [Async SSH](http://asyncssh.readthedocs.org/en/latest/)
6. Subprocess (shelling out to SSH)

Unfortunately, every library we tried we were unable to implement. The library was either not compatible with Python 3x or had licensing restrictions. This left us with concurrent subprocess calls to the SSH executable. This wasn't something that we were particularly fond of, because if you've ever seen how much code it takes to make this a viable option (just look at [Ansible's SSH executor class](https://github.com/ansible/ansible/blob/stable-2.0.0.1/lib/ansible/executor/task_executor.py#L49) you can understand it's not trivial.

Also, our final product would be a web-based GUI with a CLI utility. The library we chose must be compatible with asyncio, which will be the web framework of the final HTTP API.

## Development Schedule
We had two 6 week release cycles to come out with this installer. However, the final 6 week release cycle had 2 weeks of holiday at the end of December, so really we designed, implemented and depoyed this entire application in a total of 10 weeks. That's, 10 weeks to build a UI with a highly concurrent, asynchronous SSH library, configuration generation system which successfully preflights and postflights the cluster as well as install the DCOS - a highly available fault tolerant distributed scheduler consisting of 82 executable pieces of software (```ls /opt/mesosphere/bin | wc -l```).

No big deal.

## CM.5 - SSH Deployment MVP
For our first release cycle, CM.5, we aimed to ship a minimally viable product for installing the DCOS over SSH. No user interface yet, just a CLI utility for installing.

The CLI interface consisted of a few arguments to generate configuration, preflight hosts, install to hosts, postflight the hosts, and if required, uninstall the hosts:

```bash
optional arguments:
  -h, --help            show this help message and exit
  -l, --log-level       Verbose log output (DEBUG).
  --genconf             Execute the configuration generation (genconf).
  --preflight           Execute the preflight checks on a series of nodes.
  --deploy              Execute a deploy.
  --postflight          Execute postflight checks on a series of nodes.
  --uninstall           Execute uninstall on target hosts.
```

### YAML Configuration File
JSON is great as an interchange format for shipping data between machines. But humans are bad at remembering to double versus single quote, get all the commas (except that last line!), etc. We decided to move to a more user-friendly configuration file format with YAML. 

### Concurrent SSH Library 
CM.5 would be our MVP for our SSH library. The goal was to build a concurrent SSH library that deployed the DCOS. We would re-use this code base in CM.6 for the UI installer. 

### Inital Problems
We built out the CLI and of course ran into all the wonders of problems one runs into deploying things over SSH:

##### requiretty
By default, almost every Linux distro ships with ```/etc/sudoers``` set to ```requiretty``` to execute sudo. To fix this, we added a PTY directly to our SSH subprocess and execute SSH with ```-tt```. 

##### SSH Keys
The verdict is still out on this, but we had a lot of internal discussions about how customers will react to giving us the SSH keys to their cluster to deploy this system. 

In order to alleviate this, we designed our CLI to be the "advanced" mode. Users can still deploy the DCOS manually but supplying the correct ```bootstrap_url`` to the config.yaml file. They can opt to run the installer with ```--genconf``` only, and then manually ship the configuration artifacts as we have in the past. 

##### Paths to Things
Our installer runs in a docker container. We mount a volume on the host machine called "genconf/" which contains all the configuration artifacts. However, when we shipped CM.5 we also required users put things like ```ssh_key``` in there. This path was visable in the config.yaml file as ```ssh_key_path: /genconf/ssh_key```. But that first `/` was the root of the docker container, not the host machine. People would see this configuration parameter and change it, breaking the system since that user supplied path was on the host, not visable to the mounted volume the docker container knew about.

We fixed this by removing all paths from the config.yaml file, and ensuring our docs were up to date and very clear about what things go in the mounted `genconf/` directory.

##### Legacy Things
Users who were familiar with our legacy install patterns didn't understand right away that they don't need to ship the software on CM.5, we do that for you by default over SSH. So when they opened the config.yaml file and saw ```bootstrap_url: file:///opt/tmp_install_dir```  their inital response was to change this to the IP where they were going to ship their artifacts from. This of course broke the SSH deployment method since we automatically SCP the artifacts to that file directory on each host, then execute the install script on the host. 

We fixed this by being even more clear about that specific parameter in our docs. 

## CM.6 - UI Installer


## Lessons Learned

#### TTYs


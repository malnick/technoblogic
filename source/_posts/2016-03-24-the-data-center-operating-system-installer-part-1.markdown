---
layout: post
title: "Building an Installer for the Data Center Operating System" 
date: 2016-03-24 08:54:43 -0700
comments: true
categories: 
---
![welcome](https://dl.dropboxusercontent.com/u/77193293/Installer%20Screens/Welcome%20%28New%20User%29%401x.png)

The [Mesosphere](http://mesosphere.io) Data Center Operating System (DCOS) is a distributed, highly available task scheduler. It uses a number of open and closed source projects to make running and administering Apache Mesos as seamless and simple as possible. DCOS runs at scale (we have customers running production deployments of 50,000 nodes) across thousands of machines. This post covers challenges, design, and an overview of the final GUI installer we built to install an operating system for the data center. <!-- not sure about that last sentence --> 
<!--more-->
## Installation Challenge
Installing DCOS has always been a tricky endeavor. Every cluster has site-specific customizations that must be translated into configuration files for various pieces of the DCOS ecosystem. These configuration files need to be compiled into a shippable package, and then those packages have to be installed on tens of thousands of hosts.

For lack of a better meme,

  "One does not simply upgrade DCOS."

When you install DCOS, you need to install a specific role on each host depending on whether that host is a master, a public agent or a private agent, or just simply an agent.

Sure: this whole thing would be simple with Ansible, Puppet, or Chef. But you can't ship enterprise software and pigeonhole your paying customers into using one of these systems over the other. We are working on building a module, cookbook, and playbook for these deployment management tools, but our UI installer needs to ship DCOS to a cluster even if our customers don't use them. 

## SSH Based Installation
Mesosphere is a Python shop, so leveraging an existing library to do the SSHing would be fantastic. We vetted the following libraries:

1. [Ansible SSH Library](https://github.com/ansible/ansible)
2. [Salt SSH Library](https://docs.saltstack.com/en/latest/topics/ssh/)
3. [Paramiko](http://www.paramiko.org/)
4. [Parallel SSH](https://pypi.python.org/pypi/parallel-ssh)
5. [Async SSH](http://asyncssh.readthedocs.org/en/latest/)
6. Subprocess (shelling out to SSH)

None of these SSH libraries worked for us. The library was either not compatible with Python 3x or had licensing restrictions. This left us with concurrent subprocess calls to the SSH executable.

This wasn't an option we were particularly fond of: if you've ever seen how much code it takes to make this a viable option you can understand it's not trivial. Just look at [Ansible's SSH executor class](https://github.com/ansible/ansible/blob/stable-2.0.0.1/lib/ansible/executor/task_executor.py#L49).

Also, our final product would be a web-based GUI with a CLI utility. The library we chose had to be compatible with asyncio, which would be the web framework of the final HTTP API.

## YAML Based Configuration File Format
Previous versions of DCOS shipped what our customers know as `dcos_generate_config.sh`. This bash script is actually a self-extracting docker container that runs our configuration generation library, which builds the DCOS configuration files per input in the `config.yaml`.

This used to be in JSON format, but we moved it to a more user-friendly YAML format. In `DCOS v1.5` we shipped the first version of this new configuration file format. In `DCOS v1.6` we made a modification to the format of this file to flatten the configuration parameters so there are no nested dictionaries, simplifying the process further.

## The User Interface
Finally, we built a completely new web-based graphical user interface. Previously, DCOS end-users relied on our documentation to get the configuration parameters in their `config.yaml` correct. These parameters were a source of constant documentation updates and inputing them was prone to error. The new GUI gives our end users constant feedback about the state of their configuration, and we hope to make this experience more dynamic in the future:

![welcome](https://dl.dropboxusercontent.com/u/77193293/Installer%20Screens/Welcome%20%28New%20User%29%401x.png)

The configuration page gives you robust error information:

![configure](https://dl.dropboxusercontent.com/u/77193293/Installer%20Screens/Setup%20%28Error%29%401x.png)

The preflight process installs cluster host prerequisites for you:

![warning](https://dl.dropboxusercontent.com/u/77193293/Installer%20Screens/Setup%20%28Installation%20Warning%29%401x.png)

The preflight process gives you real-time preflight feedback across all cluster hosts:

![preflight](https://dl.dropboxusercontent.com/u/77193293/Installer%20Screens/Pre-Flight%20%28Error%29%401x.png)

All stages give you real-time status bars:

![deploy](https://dl.dropboxusercontent.com/u/77193293/Installer%20Screens/Deploy%20%28Partial%20Complete%29%401x.png)

The postflight ensures the deployment process was successful and that your cluster is ready for use:

![success](https://dl.dropboxusercontent.com/u/77193293/Installer%20Screens/Success%401x.png)

You can get a detailed log of each stage at anytime and send this to our support team if you run into problems:

![logs](https://dl.dropboxusercontent.com/u/77193293/Installer%20Screens/Log%20Modal%20%28Error%29%401x.png)

## Command Line Ready
Even though you can deploy DCOS from the web UI, we also include all the functionality on the CLI too. 

Optional arguments for the CLI are:
```bash
  -h, --help            show this help message and exit
  
  --hash-password       Hash a password on the CLI for use in the config.yaml.
  
  -v, --verbose         Verbose log output (DEBUG).
  
  --offline             Do not install preflight prerequisites on CentOS7, RHEL7 in web mode

  --web                 Run the web interface.
  
  --genconf             Execute the configuration generation (genconf).
  
  --preflight           Execute the preflight checks on a series of nodes.
  
  --install-prereqs     Install preflight prerequisites. Works only on CentOS7 and RHEL7.
  
  --deploy              Execute a deploy.
  
  --postflight          Execute postflight checks on a series of nodes.
  
  --uninstall           Execute uninstall on target hosts.
  
  --validate-config     Validate the configuration for executing genconf and deploy arguments in config.yaml
```

Deploying from the CLI is great for building the installer into your automated workflows, or using advanced configuration parameters in your config.yaml that are not currently supported by the UI. You can also skip steps that you're forced through using the UI, which is sometimes simply a matter of convenience.

If you choose this route, you'll have to execute a few different arguments to get the desired outcome of a fully deployed cluster. 

Once you've made your config.yaml and ip-detect script in a sibling directory to ```dcos_generate_config.sh``` called ```genconf/```, you can start executing configuration generation and deploy arguments to ```dcos_generate_config.sh```:

Execute configuration validation:

![val](https://dl.dropboxusercontent.com/u/77193293/Installer%20Screens/cli_validate_config_good.png)

And if configuration needs some work:

![valb](https://dl.dropboxusercontent.com/u/77193293/Installer%20Screens/cli_bad_validation.png)

Execute configuration generation:

![gen](https://dl.dropboxusercontent.com/u/77193293/Installer%20Screens/cli_genconf.png)

Execute installing prerequisists to your cluster hosts:

![prer](https://dl.dropboxusercontent.com/u/77193293/Installer%20Screens/cli_prereqs.png)

Execute preflight:

![preg](https://dl.dropboxusercontent.com/u/77193293/Installer%20Screens/cli_pre_good.png)

If things are not right in your cluster, preflight will let you know:

![preb](https://dl.dropboxusercontent.com/u/77193293/Installer%20Screens/cli_pre_errrors.png)

Execute deploy with robust state feedback:

![dep](https://dl.dropboxusercontent.com/u/77193293/Installer%20Screens/cli_bad_deploy.png)

You can also execute `--postflight` to tell you when your cluster has gained a quorum and is in a usable state. 

Optionally, if things go south, you can execute uninstall, but only after accepting the agreement:

![accpt](https://dl.dropboxusercontent.com/u/77193293/Installer%20Screens/cli_uninstall_accept.png)

Then:

![unin](https://dl.dropboxusercontent.com/u/77193293/Installer%20Screens/cli_uninstall_errors.png)

## That's It! 
And that's all there is to it, your one-stop shop to deploying your highly available, fault tolerant, enterprise-scale Data Center Operating System. We have many improvements and features we'll be adding to our new installer in the very near future. Watch this blog for more great additions to our installer.  

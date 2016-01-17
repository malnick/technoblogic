---
layout: post
title: "Mesosphere's Data Center Operating System 1.5 Release Notes"
date: 2016-01-08 13:25:31 -0800
comments: true
categories: 
---
## Synopsis
Release 1.5 of the Data Center Operating System offers a host of new changes and improvements. Most notably, DCOS 1.5 can install itself to a cluster of nodes over SSH. This feature allows end-users to setup a single host from which they can deploy their entire cluster in 3 easy commands. The release of DCOS 1.5 serves as the basis from which we're going to build our 1.6 installer, which will ship with a user interface for an even better experience. In the hopes of making DCOS the easiest distributed process scheduler to both install and use, we're also changing our configuration file format to YAML. YAML is less strict about typing, easier to read, and allows us to inline comment so we can be even more clear about what we need from you, our customer, in order to have a successful and seemless installation process. 

Along with this big changes to our installation process, we're also shipping a host of new features to DCOS which we think you'll find compelling and noteworthy. 

### Automated SSH Deployment
DCOS 1.5 installs itself to your cluster via SSH. The process can be completed in 3 easy command line steps. This removes the burden of distributing DCOS to your entire cluster manaully or putting the onus to automate this process on you, our customer. You provide the installer a SSH key, a SSH user, and a list of hosts to install DCOS and we take care of the rest.

We wrote our own, highly stable and concurrent SSH library for this process. We execute 10 concurrent SSH sessions at a time, however complete installation time is heavily dependant on network capabilities. In any case, we hope this new deployment method will enable our customers with a more seemless installation process. 

In the event that this deployment option does not fit into your architecture, you can still manually install the cluster using our installation script as has been done in the past.   

### New Configuration File Format
We have upgraded the configuration file format from JSON to YAML. We believe that YAML provides a more readable and end-user-worthy construct in which to store configuration. YAML is less strict about type and has far fewer nuances around quotes in comparison to JSON. Don't get us wrong, we love JSON! It's just that as a human being, we don't like to read it (we leave that up to machines). 

The new configuration file is constructed to allow for our SSH deployment method. We have broken the configuration file into two hashes: cluster_config and ssh_config. 

If you're familiar with our old JSON configuration file, the cluster_config should look familiar. It provides all the neccessary information to generate the DCOS configuration files. 

The ssh_config hash is new, and it provides all the neccessary information to install DCOS to your cluster over SSH. 

### CLI Options
The way in whhich you run the DCOS installer (for current users, the dcos_generate_config.sh) has also changed. 

In previous installations, you'd create a `genconf/` directory, and populate it with `config.json` and your `ip-detect` script, then execute `./dcos_generate_config.sh`. 

In order to allow you to install DCOS to your cluster over SSH, we've provided a few steps to this process:

1. `mkdir genconf/`
2. `vi genconf/config.yaml`

```yaml
---
# Cluster configuration for DCOS
cluster_config:
  # This is the local path on the target machine where the installer dumps the
  # packages and bootstrap tar ball.
  bootstrap_url: 'file:///opt/dcos_install_tmp'

  # The name of the cluster, we default to the following:
  cluster_name: 'Mesosphere: The Data Center Operating System'

  # Docker GC defaults, recommended to leave as default unless you're advanced.
  docker_remove_delay: '1hrs'

  # The default backend for Exhibitor is Zookeeper. Advanced options are
  # shared_fs and aws_s3
  exhibitor_storage_backend: zookeeper

  # If you use the default Zk backend for Exhibitor, you need to pass in
  # the IPs of the Zk cluster for it to use. This is a COMMA SEPARATED LIST,
  # not to be confused with an actual array. You must also pass the :$PORT.
  exhibitor_zk_hosts: 10.33.2.20:2181

  # This is an arbitrary path for Exhibitor to dump its zk config to.
  exhibitor_zk_path: /home/vagrant

  # More garbage collection, don't change unless you're advanced.
  gc_delay: '2days'

  # We default master discovery to a static list of masters. Advanced options
  # are 'keepalived' and 'cloud_dynamic'
  master_discovery: static

  # Since we're defaulting to master list, we pass that static list of masters.
  # Recommended deployment as at least 3 masters and a maximum of 5. It's not
  # Recommended that you deploy even number of masters.
  master_list:
  - 10.33.2.21

  # This is the list of upstream DNS resolvers that Mesos DNS will use.
  resolvers:
  - 8.8.8.8
  - 8.8.4.4

  # Default roles, do not change unless you're advanced.
  roles: slave_public

  # Default weights, do not change unless you're advanced.
  weights: slave_public=1

# SSH Configuration for --preflight/--deploy/--postflight/--clean-dcos
ssh_config:
  # It's recommended to rotate keys in the cluster after deployment.
  # It is recommended to copy your private SSH key to the genconf/
  # directory which is mounted to /genconf inside the installer
  # docker container. Changing this to a path on the host machine will mean the installer
  # can not find the key, since /genconf is mounted by default in the installer script.
  ssh_key_path: /genconf/ssh_key

  # The default SSH port for the SSH installation process.
  ssh_port: '22'

  # The default SSH user to SSH into the target machines for installation. Users
  # must have root priviledges on the host machines.
  ssh_user: vagrant

  # The complete list of IPv4 addresses to the target DCOS hosts including masters.
  target_hosts:
  - 10.33.2.21
  - 10.33.2.24

  # The directory on the installer host to dump logs from the SSH processes to. This
  # should not be changed as /genconf is local to the container running the installer,
  # and is a mounted volume.
  log_directory: /genconf/logs
  process_timeout: 120
```

We determine which nodes to install as masters and which are agents by deduction of what you give us as 'master_list' in the `cluster_config` section. 

3. create genconf/ip-dtect 
4. copy in $YOUR_SSH_KEY to genconf/ssh_key
5. `./dcos_generate_config.sh --genconf` -> creates configuration files for DCOS, builds packages.
6. `./dcos_generate_config.sh --preflight` -> SSH's each host and executes the preflight script. Run this with `-l debug` to see verbose output, else only errors are shown.
7. `./dcos_generate_config.sh --deploy` -> SSH's each host and installs DCOS. 
8. `./dcos_generate_config.sh --postflight` -> SSH's each host and determines if DCOS has been installed correctly. You may need to wait up to 15 minutes before this fully takes effect due to the nature of bootstrapping the DCOS zookeeper service.
9. In the event that things went south or you need to start from scratch, `./dcos_generate_config.sh --uninstall` will completely remove DCOS from your cluster. 



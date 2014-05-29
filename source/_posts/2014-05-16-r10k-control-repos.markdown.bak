---
layout: post
title: "r10k: Control Repos"
date: 2014-05-16 12:34:33 -0700
comments: true
categories: 
---
This document explains the architecture and deployment of a control repository for syncing multiple puppet environments, their associated puppet code (modules) and their assocaited data (hiera). This document does not review how to deploy r10k, however that is discussed in relevant detail [here](https://github.com/puppetlabs/prosvcs-malnick/blob/master/README.md#deploy-git-r10k-and-stuff).

##What is a control repo?

A control repository stores a Puppetfile and hiera data (hiera.yaml and hieradata/).

###What does it contain?

	hieradata/
	Puppetfile

It is also common to have a ```hiera.yaml``` in the control repo. However [for many reasons](http://www.jeffmalnick.com/blog/2014/05/15/hiera-and-r10k/) I don't believe this is a good idea. It can lead to confusing issues with branching of the file that is only consulted once for it's ```$datadir``` path and is not used on a per environment basis - it's loaded once from ```$confdir``` during the *hiera()* call and is not consulted on a per environment basis (e.g. ```$confdir/environments/$environments/hiera.yaml``` **is not used** during the *hiera()* lookup, only ```$confdir/hiera.yaml``` is used). 
##How does it work?

The control repo is placed in a monolithic git repository. 

The repository can have one or more topic branches that are used by r10k to sync to local Puppet environments. 

###Configuration for Puppet code & Hiera data sync via r10k

Details on how to deploy a gitlab repo and assocaited topic branching for r10k sync are [here](https://github.com/puppetlabs/prosvcs-malnick/blob/master/README.md#deploy-git-r10k-and-stuff). 

Place a Puppetfile in ```$confdir/Puppetfile```.

Populate your Puppetfile with what ever crap you need. 

In ```$confdir```:

```bash
git init
git remote add origin git@whatever.com:your_name/control_repo.git
git branch -m master production
git add Puppetfile
git add hiera.yaml # r10k really doesn't need this but we'll add it anyways. 
git add hieradata/
git push -u origin production:production # or whatever branch, maybe production?
```

###Configure hiera.yaml for dynamic environments

**NOTE**: the hiera.yaml is only loaded from ```$confdir/hiera.yaml``` on each puppet run, this means even though you'll have a hiera.yaml in ```$confdir/environments/$environment/``` those are not actually consulted, only the $confdir hiera.yaml is used - therefore, ***you can not have hierarchies per environment***. Since the ```$datadir``` is environment aware that namespace is filled at run time, and consults the specific environment datadir ```$confdir/environments/$environment/hieradata/```. 

Your hiera.yaml needs to have a ```datadir``` configured for dynamic lookup so:

```yaml
---
:backends:
  - yaml
:hierarchy:
  - "%{clientcert}"
  - "%{environment}"
  - global

:yaml:
  :datadir: '/etc/puppetlabs/puppet/environments/%{::environment}/hieradata'
```

###Branching your Puppetfile
For example, assuming you already have a master or production branch:

```bash
vi Puppetfile
```
...add some git modules etc...

```bash
git checkout -b development
git push origin development:development
git commit -am Puppetfile
r10k deploy environment -pv
```
Now you have a new topic branch 'development' and a new Puppet environment in ```$confdir/environments/development```.

###Branching your hiera data

Our ```development``` branch needs it's own data too:

```bash
cd $confdir/hieradata
```

* modify K,V's in ```whatever.yaml```
* modify other K,V's as needed for your development environment


```bash
git branch # check your branch, make sure it's still development
git commit -am hieradata
git push 
r10k deploy environment -pv
```

Check ```$confdir/environments/development/hieradata```

##Testing
###Configuration files for r10k, hiera, puppet:

####/etc/r10k.yaml
```bash
root@master hieradata]# cat /etc/r10k.yaml
:cachedir: /var/cache/r10k
:sources:
  puppet:
    remote: "git@10.10.100.111:user/control_repo.git"
    basedir: /etc/puppetlabs/puppet/environments
    prefix: false
:purgedirs:
  - ""
```
####/etc/puppetlabs/puppet/puppet.conf
```bash
[root@master hieradata] cat /etc/puppetlabs/puppet/puppet.conf
[main]
certname = master.puppetlabs.vm
dns_alt_names = master.puppetlabs.vm,puppet
vardir = /var/opt/lib/pe-puppet
logdir = /var/log/pe-puppet
rundir = /var/run/pe-puppet
modulepath = /etc/puppetlabs/puppet/environments/$environment/modules:/opt/puppet/share/puppet/modules
server = master.puppetlabs.vm
user  = pe-puppet
group = pe-puppet
archive_files = true
archive_file_server = master.puppetlabs.vm
# cut [master] & [agent] sections, $modulepath above is the important config key here.
```
####/etc/puppetlabs/puppet/hiera.yaml
```bash
[root@master puppet] cat hiera.yaml
---
:backends:
  - yaml
:hierarchy:
  - "%{clientcert}"
  - "%{environment}"
  - global
:yaml:
  :datadir: '/etc/puppetlabs/puppet/environmets/%{environment}/hieradata'
```
####/etc/puppetlabs/puppet/Puppetfile
```bash
[root@master puppet]# cat Puppetfile
# mod, <module name>, <version or tag>, <source>
forge "http://forge.puppetlabs.com"

# Modules from the Puppet Forge
mod "puppetlabs/stdlib"
mod "puppetlabs/apache", "0.11.0"
mod "puppetlabs/pe_gem"
mod "puppetlabs/mysql"
mod "puppetlabs/firewall"
mod "puppetlabs/vcsrepo"
mod "puppetlabs/git"
mod "puppetlabs/inifile"
mod "zack/r10k"
mod "gentoo/portage"
mod "thias/vsftpd"


# Modules from Github using various references
mod "wordpress",
  :git => "git://github.com/hunner/puppet-wordpress.git",
  :ref => '0.4.0'
```
###Testing the Puppet Master ```master.puppetlabs.vm:$confdir/```:

####Our topic branches:

```bash
[root@master puppet] git branch
  development
* production
  staging
```

####For the given topic branch above, production, let's look at our hieradata in ```$confdir/hieradata```:

```bash
[root@master hieradata] pwd
/etc/puppetlabs/puppet/hieradata
[root@master hieradata] ls
agent1.puppetlabs.vm.yaml  agent2.puppetlabs.vm.yaml  agent3.puppetlabs.vm.yaml  master.puppetlabs.vm.yaml
```

####and for each of these files we have the same K,V:

```bash
[root@master hieradata] cat master.puppetlabs.vm.yaml
---
message: "%{fqdn} is running in environment %{environment}"
[root@master hieradata] cat agent1.puppetlabs.vm.yaml
---
message: "%{fqdn} is running in environment %{environment}"
```

###Now let's switch over to our development branch and compare:

```bash
[root@master puppet] git checkout development
Switched to branch 'development'
root@master hieradata] pwd
/etc/puppetlabs/puppet/hieradata
[root@master hieradata] ls
agent1.puppetlabs.vm.yaml  agent2.puppetlabs.vm.yaml  agent3.puppetlabs.vm.yaml  master.puppetlabs.vm.yaml
[root@master hieradata] cat agent1.puppetlabs.vm.yaml
---
message: "%{fqdn} is running in environment %{environment}"
[root@master hieradata] cat master.puppetlabs.vm.yaml
---
message: "%{fqdn} is running in environment %{environment}"
```

Sync everything up with r10k so we can test:

```bash
[root@master puppet] r10k deploy environment -pv
[R10K::Task::Deployment::DeployEnvironments - INFO] Loading environments from all sources
[R10K::Task::Environment::Deploy - NOTICE] Deploying environment staging
[R10K::Task::Puppetfile::Sync - INFO] Loading modules from Puppetfile into queue
[R10K::Task::Environment::Deploy - NOTICE] Deploying environment production
[R10K::Task::Puppetfile::Sync - INFO] Loading modules from Puppetfile into queue
[R10K::Task::Module::Sync - INFO] Deploying wordpress into /etc/puppetlabs/puppet/environments/production/modules
[R10K::Task::Module::Sync - INFO] Deploying vsftpd into /etc/puppetlabs/puppet/environments/production/modules
[R10K::Task::Module::Sync - INFO] Deploying portage into /etc/puppetlabs/puppet/environments/production/modules
[R10K::Task::Module::Sync - INFO] Deploying r10k into /etc/puppetlabs/puppet/environments/production/modules
[R10K::Task::Module::Sync - INFO] Deploying inifile into /etc/puppetlabs/puppet/environments/production/modules
[R10K::Task::Module::Sync - INFO] Deploying git into /etc/puppetlabs/puppet/environments/production/modules
[R10K::Task::Module::Sync - INFO] Deploying vcsrepo into /etc/puppetlabs/puppet/environments/production/modules
[R10K::Task::Module::Sync - INFO] Deploying firewall into /etc/puppetlabs/puppet/environments/production/modules
[R10K::Task::Module::Sync - INFO] Deploying mysql into /etc/puppetlabs/puppet/environments/production/modules
[R10K::Task::Module::Sync - INFO] Deploying pe_gem into /etc/puppetlabs/puppet/environments/production/modules
[R10K::Task::Module::Sync - INFO] Deploying apache into /etc/puppetlabs/puppet/environments/production/modules
[R10K::Task::Module::Sync - INFO] Deploying stdlib into /etc/puppetlabs/puppet/environments/production/modules
[R10K::Task::Environment::Deploy - NOTICE] Deploying environment master
[R10K::Task::Puppetfile::Sync - INFO] Loading modules from Puppetfile into queue
[R10K::Task::Environment::Deploy - NOTICE] Deploying environment development
[R10K::Task::Puppetfile::Sync - INFO] Loading modules from Puppetfile into queue
[R10K::Task::Deployment::PurgeEnvironments - INFO] Purging stale environments from /etc/puppetlabs/puppet/environments
```


Since there is a ```%{certname}.yaml``` for the master we can do a quick check on the command line that we're accessing the correct data:

```bash
[root@master puppet] git checkout production
Already on 'production'

[root@master puppet] puppet apply -e "notice(hiera(message))"
Notice: Scope(Class[main]): master.puppetlabs.vm is running in environment production
Notice: Compiled catalog for master.puppetlabs.vm in environment production in 0.06 seconds
Notice: Finished catalog run in 0.24 seconds
[root@master puppet]
```

The ```$fqdn``` and ```$environment``` values were correctly filled in. **Note** that this is a poor test since my data files are essentially all the same, ```$environment``` will always match it's environment and ```$fqdn``` will always match it's fqdn -  we could be grabbing this value from anywhere. So Let's try with hard coded values:

```bash
[root@master hieradata] pwd
/etc/puppetlabs/puppet/hieradata
[root@master hieradata] git branch
  development
* production
  staging
[root@master hieradata] cat master.puppetlabs.vm.yaml
---
message: "I'm hard coding this value: environment production, master.puppetlabs.vm.yaml"
```

Now push your new data for production branch up to gitlab

```
[root@master puppet]# git add hieradata/
[root@master puppet]# git commit -m "hieradata hard coded"
[production 3a58e49] hieradata hard coded
 1 files changed, 1 insertions(+), 1 deletions(-)
 [root@master puppet]# git push
 Counting objects: 7, done.
 Delta compression using up to 4 threads.
 Compressing objects: 100% (4/4), done.
 Writing objects: 100% (4/4), 399 bytes, done.
 Total 4 (delta 2), reused 0 (delta 0)
 To git@10.10.100.111:user/control_repo.git
    1b240c6..3a58e49  production -> production
```

and sync r10k

```
[root@master puppet]# r10k deploy environment -pv
[R10K::Task::Deployment::DeployEnvironments - INFO] Loading environments from all sources
[R10K::Task::Environment::Deploy - NOTICE] Deploying environment staging
[R10K::Task::Puppetfile::Sync - INFO] Loading modules from Puppetfile into queue
[R10K::Task::Environment::Deploy - NOTICE] Deploying environment production
[R10K::Task::Puppetfile::Sync - INFO] Loading modules from Puppetfile into queue
# ommitting other output ...
```

and test for the correct hard coded K,V

```
[root@master puppet]# puppet apply -e "notice(hiera(message))"
Notice: Scope(Class[main]): I'm hard coding this value: environment production, master.puppetlabs.vm.yaml
Notice: Compiled catalog for master.puppetlabs.vm in environment production in 0.05 seconds
Notice: Finished catalog run in 0.26 seconds
```

YAY!

####And again on the development branch
```bash
[root@master hieradata] pwd
/etc/puppetlabs/puppet/hieradata
[root@master hieradata] git branch
* development
  production
  staging
[root@master puppet] cat hieradata/master.puppetlabs.vm.yaml
---
message: "I'm hard coding this value: environment development, master.puppetlabs.vm.yaml"
```

Push our new hieradata for ```development``` to gitlab:

```bash
[root@master puppet] git add hieradata/
[root@master puppet] git commit -m "hieradata hard coded"
[development 2873db5] hieradata hard coded
 1 files changed, 1 insertions(+), 1 deletions(-)
[root@master puppet] git push
Counting objects: 7, done.
Delta compression using up to 4 threads.
Compressing objects: 100% (4/4), done.
Writing objects: 100% (4/4), 398 bytes, done.
Total 4 (delta 2), reused 0 (delta 0)
To git@10.10.100.111:user/control_repo.git
   08e249b..2873db5  development -> development
```

andthen sync with r10k 

```
[root@master puppet]# r10k deploy environment -pv
[R10K::Task::Deployment::DeployEnvironments - INFO] Loading environments from all sources
[R10K::Task::Environment::Deploy - NOTICE] Deploying environment staging
[R10K::Task::Puppetfile::Sync - INFO] Loading modules from Puppetfile into queue
[R10K::Task::Environment::Deploy - NOTICE] Deploying environment production
[R10K::Task::Puppetfile::Sync - INFO] Loading modules from Puppetfile into queue
# ommitted the other output...
```

and test with the ```--environment development``` switch

```
[root@master puppet]# puppet apply -e "notice(hiera(message))" --environment development
Notice: Scope(Class[main]): I'm hard coding this value: environment development, master.puppetlabs.vm.yaml
Notice: Compiled catalog for master.puppetlabs.vm in environment development in 0.05 seconds
Notice: Finished catalog run in 0.25 seconds
````


We can also do a quick one time environment run with the ```--environment``` flag:









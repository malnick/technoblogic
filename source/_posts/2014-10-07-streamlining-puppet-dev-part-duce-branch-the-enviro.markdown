---
layout: post
title: "Streamlining Puppet Dev Part Duce: Branch the enviro"
date: 2014-10-07 14:31:39 -0700
comments: true
categories: 
---
Most companies don't have a single monolithic application, today most applications evolve out of lots of atomic services: thus, service oriented architecture. 

What this means for your development environment is that you end up having many different applications, which is many cases are atomic services and in other cases are a conglomeration of services. Either way, you end up with a need for many dev environments. 

At Connect Solutions we have several environments that require infrastructure development. The main ones are our custom load balancer (we call it MTLB), our Connect Cluster, CQ, and our Connect Experience applications. 

In order to streamline our dev process with Puppet we created a repo called 'puppet-dev-enviro' that deploys VM's with Vagrant and manages what modules you want to test via Rake & r10k. 

For any given envio we like to mirror what it looks like in prod as best we can. Therefore, any enviro always uses the version of puppet we run in prod on a separate Puppet Master, then the nodes that make of the rest of the enviro. 

A simple example, theMTLB enviro deploys a Puppet Master and an MTLB load balancer node. 

## Enviro Management
Since we have so many enviros we branch the 'puppet-dev-enviro' repo for each one. So if you're testing MTLB code the workflow looks like this:

```
cd puppet-dev-enviro
git checkout mtlb
MONO=true rake deploy
```

Those first two commands are pretty straight forward. However, the deploy command probably needs some explanation. I wrote this task to streamline our development pipeline. It's main functionality is to read from a subdirectory called puppet and a file called the Puppetfile.

You might be familiar with the Puppetfile concept if you've used Puppet Librarian or r10k. In this task, I actually invoke r10k locally on the Puppetfile to pull down all the modules listed in it to puppet/modules. In the case of Connect Solutions, we're currently in the process of moving our legacy puppet module structure from a monolithic one to their own atomic repos. This isn't complete yet, so the MONO=true env variable envokes a subcommand in deploy to rip out all the sub-modules of this monolithic repo and place them in puppet/modules. 

'Deploy' also supports hiera data management by checking for our `puppet-configuration` repo in the puppet/modules directory. If it's listed in the Puppetfile this repo will be present here. If so, it moves all the data from puppet-configuration into puppet/data. 

Both ```puppet/modueles``` and ```puppet/data``` are shared with the puppet master VM deploed with Vagrant. As a Vagrant post-provisioning step I blow away the ```/etc/puppetlabs/puppet/modules```, ```/etc/puppetlabs/puppet/data``` directories and sym link the shared modules and data directories out of ```/tmp```. 

#### The Deploy Task
```
desc 'Deploying modules form Puppetfile and booting master and agent VMs' 
task :deploy do
  puts "Building out Puppet module directory..."
  confdir = Dir.pwd
  # Check directory structure:
  puts "Checking for puppet/modules..."
  unless Dir.exists?("#{confdir}/puppet/modules")
	  puts "puppet/modules not found, creating." 
	  Dir.mkdir("#{confdir}/puppet/modules")
  end
  puts "Checking for puppet/data..."
  unless Dir.exists?("#{confdir}/puppet/data")
	  puts "puppet/data not found, creating."
	  Dir.mkdir("#{confdir}/puppet/data")
  end
  
  moduledir = "#{confdir}/puppet/modules"
  puppetfile = "#{confdir}/puppet/Puppetfile"
  puts "Placing modules in #{moduledir}"
  puts "Using Puppetfile at #{puppetfile}"
  unless system("PUPPETFILE=#{puppetfile} PUPPETFILE_DIR=#{moduledir} /usr/bin/r10k puppetfile install")
    abort 'Failed to build out Puppet module directory. Exiting...'
  end
  if Dir.exists?("#{moduledir}/puppet-configuration/")
	puts "Detected puppet data repo, copying contents to #{confdir}/puppet/data"
  	unless system("cp -Rv #{moduledir}/puppet-configuration/* #{confdir}/puppet/data/")
		abort "Failed to move puppet-configuration"
	end
  end
  if mono
	puts "Moving modules out of monolithic dir #{moduledir}/puppet-modules to #{moduledir}"
	unless system("mv #{moduledir}/puppet-modules/* #{moduledir}")
		abort "Failed to move modules from monolithic repo to #{moduledir}"
	end
  end
  puts "Bringing up vagrant machines"
  unless system("vagrant up --provider virtualbox") 
	  abort 'Vagrant up failed. Exiting...'
  end
  puts "Vagrant Machines Up Successfully\n"
end
```

This structure allows us to play around with the module code on the fly from the host VM, with our own dotfiles and local editing or preferred pipelines. For example, I am a heavy Vim user, however, a lot of my colleagues are Sublime text users. You can choose what method best suites you and not be beholden to who provisioned the VM .box file beforehand. 

For large code-base changes, i.e., developing an entireley new topic branch, this pipeline allows seamless integration with git and enables better version control management. An example workflow would be:

1. Open two screen or tmux sessions
2. In one session cd into ```/path/to/monolithic/puppet-modules/test-mod/manifests```
3. In the other session cd into ```/path/to/puppet-dev-enviro```
4. In ```puppet-dev-enviro```:
	1. git checkout my-enviro
	2. update ```puppet/Puppetfile``` and ```puppet/manifests/site.pp``

puppet/Puppetfile:

```
'puppet-modules', :git => git@github.com:connectsolutions/puppet-modules', :ref => 'my-topic-branch'
'puppet-configuration', :git => git@github.com:connectsolutions/puppet-configuration'
```

puppet/manifests/site.pp:

```
node 'my.node.dev` {
	include my::class
}
```

DEPLOY: In `puppet-dev-enviro` run ```MONO=true rake deploy```

This will now pull down and configure the environment for the VM's. When finished, all the puppet data and modules will be live on the master VM. 

### Enviro-Specific Vagrantfile
One step I've skipped here however is making a git-branch for my-enviro. That's a completely different step but mainly involves updateing the Vagrantfile with the neccessary VM information. I won't cover that here since that is specific to every enviro the same way Puppet code is speciic to each module. I will however share what stays the same between most Vagrantfiles in each enviro and that is the Master VM configuration block:

```
Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  config.vm.box = "ubuntuamd64"
  config.vm.box_url = "https://cloud-images.ubuntu.com/vagrant/precise/current/precise-server-cloudimg-amd64-vagrant-disk1.box"
  config.pe_build.download_root = 'https://s3.amazonaws.com/pe-builds/released/:version'
  config.pe_build.version = "3.3.0"
  config.ssh.forward_agent  = true

  config.vm.define :master do |master|
    master.vm.provider :virtualbox do |v|
      v.memory = 2048
  v.cpus = 1
    end
    master.vm.network :private_network, ip: "10.28.126.141"
    master.vm.hostname = 'master.dev'
    master.vm.provision :hosts
    master.vm.provision :pe_bootstrap do |pe|
      pe.role = :master
    end
    master.vm.synced_folder "puppet/modules", "/tmp/modules"
    master.vm.synced_folder "puppet/manifests", "/tmp/manifests"
    master.vm.synced_folder "puppet/data", "/tmp/data"
    master.vm.synced_folder "puppet/filestore", "/tmp/filestore"
    master.vm.synced_folder "puppet/", "/tmp/puppet"
    master.vm.provision "shell", inline: "rm -rf /etc/puppetlabs/puppet/modules/ && ln -s /tmp/modules/ /etc/puppetlabs/puppet/"
    master.vm.provision "shell", inline: "rm -rf /etc/puppetlabs/puppet/manifests/ && ln -s /tmp/manifests/ /etc/puppetlabs/puppet/"
    master.vm.provision "shell", inline: "rm -rf /etc/puppetlabs/puppet/data && ln -s /tmp/data/ /etc/puppetlabs/puppet/"
    master.vm.provision "shell", inline: "ln -s /tmp/filestore/ /etc/puppetlabs/puppet/"
    master.vm.provision "shell", inline: "rm /etc/puppetlabs/puppet/hiera.yaml && ln -s /tmp/puppet/hiera.yaml /etc/puppetlabs/puppet/hiera.yaml"
    master.vm.provision "shell", inline: "ln -s /tmp/puppet/fileserver.conf /etc/puppetlabs/puppet/fileserver.conf"
  end
```

### Code Test -> Develop Pipeline
Once the VM's are up and running you can ssh into the VM under test and run `puppet agent -t`. If everything went as planned the agent will get a catlog from the master and start configuring itself. If you're like me, it didn't work on the first try. Now we need to update our code-base. 

In the screen or tmux session that is CD'ed to your `puppet-modules` directory go into the manifests dir of the code in question. Edit that code or make whatever changes are needed for further testing. 

Keep in mind we are working on our `my-topic-branch` branch of the `puppet-modules` repo. So when we're done making the local changes:

```
git add my-class.pp
git commit -m "I made changes"
git push origin my-topic-branch
```

Then in the other screen window that's in the `puppet-dev-enviro` directory run:

```
MONO=true rake pull
```

This runs only r10k and the workflow neccessary to pull down the new Puppet code. It is a heavy operation if you have a LOT of code in that Puppetfile. We haven't ran into an issue with that yet however for our individual test enviros. The :pull task looks like this:

```
desc 'Pull down modules in Puppetfile'
task :pull do
	puts "This will blow away everything in puppet/modules. Are you sure you want to continue? [y/n]"
	ans = STDIN.gets
	if ans =~ /^y/
		confdir = Dir.pwd
		moduledir = "#{confdir}/puppet/modules"
		puppetfile = "#{confdir}/puppet/Puppetfile"
		puts "Pulling down new modules in #{puppetfile} to #{moduledir}"
		unless system("PUPPETFILE=#{puppetfile} PUPPETFILE_DIR=#{moduledir} /usr/bin/r10k puppetfile install")
			abort 'Failed to build out Puppet module directory. Exiting...'
		end
		puts "New modules successfully pulled down" 
		if mono
			puts "Moving modules out of monolithic dir #{moduledir}/puppet-modules to #{moduledir}"
			unless system("mv #{moduledir}/puppet-modules/* #{moduledir}")
				abort "Failed to move modules from monolithic repo to #{moduledir}"
			end
		end
		if Dir.exists?("#{moduledir}/puppet-configuration/")
  			unless system("cp -Rv #{moduledir}/puppet-configuration/* #{confdir}/puppet/data/")
				abort "Failed to move puppet-configuration"
			end
  		end
	else puts "Exiting..."
		exit
	end
end
```

Now you have new code in your master VM, run `puppet agent -t` again on your agent. 

### Wait a minute!
Some will say, "This is more work than before. Now I have this extra git step!". Yup, that's right, you're forced to commit your changes to your own topic branch before you test on your local machine. Yes, this isn't good for doing work on the airplane. Granted, this test enviro as it currently stands isn't designed for the latter, it's designed towards ***seamless collaboration***.

What do I mean by that? I mean, I don't want to have the conversation with a colleage at 4PM on a Thursday night that goes like this: "Hey, I need to collaborate on your code. Can you push it to a topic branch in git for me?" "Sure, I'll do that as soon as I get home tonight after picking up the kids and making dinner." "Great!" ... The following day: "So hey, I REALLY wanted to test out that code we need in prod by this afternoon last night, but I never saw a push for your branch." "Yeah, sorry, I got caught up in stuff. You know, life!".

That 'extra' git step ensures all the development steps are being tracked, and anyone at anytime can spin up this environmnet with the exact same Puppetfile and site.pp configuration and get similar testing results. 

Some day, I'll put together a local-only development environment but for now this is not the purpose of what we've created here. 

---
layout: post
title: "Agile Dev Environment for Puppet Code"
date: 2014-07-21 12:15:51 -0700
comments: true
categories: 
---
When ever I am creating a new Puppet module or working on someone else's Puppet module I constantly look for ways to make more efficient the development process. 

It may not seem like a lot of time but all those 'vagrant up' 'vagrant destroy' 'git pull' 'git commit' '...push, branch...' etc turn into a lot of time wasted. 

What I need is an easy way to pull in git-based (or forge-based) modules to a VM and have them available locally to edit with my favorite editor. 

This environment needs to satisfy these needs:

1. I can edit my code on my host machine in my favorit editor (vim) which has all my favorite plugins
2. The code is live on the VM, sym linked from the VM to my host so I don't have to git push/pull to update the VM (or some other jank process)
3. I can easily deploy many modules/dependances for the code to the VM with a simple Rake command

## Solution
To solve this development issue I forked a loanly project from nval0. It was a basic Rakefile which was using Puppet-librarian to pull in modules from a Puppetfile.

The environment used:

1. Puppet librarian for module management via Puppetfile
2. Vagrant VMs
3. Wrapped up some of the commands into a Rakefile (gem prereq's etc)

After playing with this environment for a bit I realized some drawbacks:

1. Puppet-librarian only worked on ruby 1.9
2. I wanted a rake task to 'deploy' everything in the Puppetfile to sym-linked dir to the VM

The first draw back was easily solved, instead of using Puppet-librarian I'd use [r10k](https://github.com/adrienthebo/r10k). R10k builds off of Puppet-libarian and is most often used to map git branches for any Puppet module to local Puppet environments on a Puppet Master. However, you can use it in a similar fashion to Puppet-libarian where it only reads a Puppetfile then pulls in those modules directly. The great thing is it works on all major releases of Ruby so my dev environment will not need rbenv or another ruby environment manager.

### Let's put this together into some rake tasks:

An example rake task to deploy the Puppetfile modules with r10k:

{% codeblock lang:ruby %}
desc 'Pull down modules in Puppetfile'
task :pull do
	confdir = Dir.pwd
	moduledir = "#{confdir}/puppet/modules"
	puppetfile = "#{confdir}/puppet/Puppetfile"
	puts "Pulling down new modules in #{puppetfile} to #{moduledir}"
	unless system("PUPPETFILE=#{puppetfile} PUPPETFILE_DIR=#{moduledir} /usr/bin/r10k puppetfile install")
		abort 'Failed to build out Puppet module directory. Exiting...'
	end
	puts "New modules successfully pulled down"
end
{% endcodeblock %}

This first rake task uses r10k to read the Puppetfile and pull down the modules listed in it to the module directory. 

Let's link this directory into the VM via the Vagrantfile, this way we can edit the code locally on the host while having it available to run on the Master VM:

{% codeblock lang:ruby %}
config.vm.define :master do |master|
	master.vm.network :private_network, ip: "10.10.100.100"
	master.vm.hostname = 'master.puppetlabs.vm'
	master.vm.provision :hosts
	master.vm.provision :pe_bootstrap do |pe|
		pe.role = :master
	end
	master.vm.synced_folder "puppet/modules", "/tmp/modules"
	master.vm.synced_folder "puppet/manifests", "/tmp/manifests"
	master.vm.provision "shell", inline: "service iptables stop"
	master.vm.provision "shell", inline: "rm -rf /etc/puppetlabs/puppet/modules/ && ln -s /tmp/modules/ /etc/puppetlabs/puppet/"
	master.vm.provision "shell", inline: "rm -rf /etc/puppetlabs/puppet/manifests/ && ln -s /tmp/manifests/ /etc/puppetlabs/puppet/"
end
{% endcodeblock %}

Why did I use the shell provisioner to sym link /tmp/modules and /tmp/manifests to ```$confdir/modules``` and ```$confdir/manifests```? 

The pe_build plugin for Vagrant will provision the master using the default Puppet Enterprise installer. However, the installer will fail if any PE-related directories already exist (/opt/puppet or /etc/puppetlabs for example).
To get around this, and still have live dir's provisioned on the VM I couldn't use the vagrant ```synced_folder``` method since that will run before the provisioners run (vagrant needs to build the machine before running any type of configuration managment on it) - the PE installer will blow up when the plugin runs since I have to sync into /etc/puppetlabs/puppet. 

So instead of syncing into a PE-specific PATH I sync into /tmp, and then when the provisioner finishes (provisioners are ran in order) I can sym link the PE-specific module and manifests dir's from /tmp. 

### Complete Vagrantfile:

{% codeblock lang:ruby %}


Now we have a Rakefile that wraps up some deploy commands and a
# -*- mode: ruby -*-
# vi: set ft=ruby :
# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = "2"
Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  config.vm.box = "centos-64-x64-vbox4210.box"
  config.vm.box_url = "http://puppet-vagrant-boxes.puppetlabs.com/centos-64-x64-vbox4210.box" 
  config.pe_build.download_root = 'https://s3.amazonaws.com/pe-builds/released/:version'
  config.pe_build.version = "3.2.3"

## Master
  config.vm.define :master do |master|
    master.vm.network :private_network, ip: "10.10.100.100"
    master.vm.hostname = 'master.puppetlabs.vm'
    master.vm.provision :hosts
    master.vm.provision :pe_bootstrap do |pe|
      pe.role = :master
    end
    master.vm.synced_folder "puppet/modules", "/tmp/modules"
    master.vm.synced_folder "puppet/manifests", "/tmp/manifests"
    master.vm.provision "shell", inline: "service iptables stop"
    master.vm.provision "shell", inline: "rm -rf /etc/puppetlabs/puppet/modules/ && ln -s /tmp/modules/ /etc/puppetlabs/puppet/"
    master.vm.provision "shell", inline: "rm -rf /etc/puppetlabs/puppet/manifests/ && ln -s /tmp/manifests/ /etc/puppetlabs/puppet/"
  end

## Agent 
  config.vm.define :agent1 do |agent|
    agent.vm.network :private_network, ip: "10.10.100.111"
    agent.vm.hostname = 'agent1.puppetlabs.vm'
    agent.vm.provision :hosts
    agent.vm.provision :pe_bootstrap do |pe|
      pe.role   =  :agent
      pe.master = 'master.puppetlabs.vm'
    end
  end
{% endcodeblock %}

Now I have an easy to use Vagrantfile that can boot my master with sym linked module and manifests dirs and an agent to test on.

Now we need to finish out that Rakefile, adding in some dependancy checks and some tasks to setup, deploy, pull (modules on the fly) and destroy as needed:

{% codeblock lang:ruby %}

begin
  require 'os'
  require 'ptools'
rescue LoadError => e
  puts "Error during requires: \t#{e.message}"
  abort "You may be able to fix this problem by running 'bundle'."
end

task :default => 'deps'

necessary_programs = %w(VirtualBox vagrant)
necessary_plugins = %w(vagrant-auto_network vagrant-pe_build vagrant-vmware-fusion)
necessary_gems = %w(bundle r10k)

desc 'Check for the environment dependencies'
task :deps do
  puts 'Checking environment dependencies...'

  printf "Is this a POSIX OS?..."
  unless OS.posix?
    abort 'Sorry, you need to be running Linux or OSX to use this Vagrant environment!'
  end
  puts "OK"
 
  necessary_programs.each do |prog| 
    printf "Checking for %s...", prog
    unless File.which(prog)
      abort "\nSorry but I didn't find require program \'#{prog}\' in your PATH.\n"
    end
    puts "OK"
  end

  necessary_plugins.each do |plugin|
    printf "Checking for vagrant plugin %s...", plugin
    unless %x{vagrant plugin list}.include? plugin
      puts "\nSorry, I wasn't able to find the Vagrant plugin \'#{plugin}\' on your system."
      abort "You may be able to fix this by running 'rake setup\'.\n"
    end
    puts "OK"
  end

  necessary_gems.each do |gem|
    printf "Checking for Ruby gem %s...", gem
    unless system("gem list --local -q --no-versions --no-details #{gem} | egrep '^#{gem}$' > /dev/null 2>&1")
      puts "\nSorry, I wasn't able to find the \'#{gem}\' gem on your system."
      abort "You may be able to fix this by running \'gem install #{gem}\'.\n"
    end
    puts "OK"
  end

  printf "Checking for additional gems via 'bundle check'..."
  unless %x{bundle check}
    abort ''
  end
  puts "OK"

  puts "\n" 
  puts '*' * 80
  puts "Congratulations! Everything looks a-ok."
  puts '*' * 80
  puts "\n"
end

desc 'Install the necessary Vagrant plugins'
task :setup do
  necessary_plugins.each do |plugin|
    unless system("vagrant plugin install #{plugin} --verbose")
      abort "Install of #{plugin} failed. Exiting..."
    end
  end

  necessary_gems.each do |gem|
    unless system("gem install #{gem}")
      abort "Install of #{gem} failed. Exiting..."
    end
  end

  unless %x{bundle check} 
    system('bundle install')
  end

end

desc 'Deploying modules form Puppetfile and booting master and agent VMs' 
task :deploy do
  puts "Building out Puppet module directory..."
  confdir = Dir.pwd
  moduledir = "#{confdir}/puppet/modules"
  puppetfile = "#{confdir}/puppet/Puppetfile"
  puts "Placing modules in #{moduledir}"
  puts "Using Puppetfile at #{puppetfile}"
  unless system("PUPPETFILE=#{puppetfile} PUPPETFILE_DIR=#{moduledir} /usr/bin/r10k puppetfile install")
    abort 'Failed to build out Puppet module directory. Exiting...'
  end
  puts "Bringing up vagrant machines"
  unless system("vagrant up master agent1") 
	  abort 'Vagrant up failed. Exiting...'
  end
  puts "Vagrant Machines Up Successfully\n"
  puts "Access master at 'vagrant ssh master' or 'ssh vagrant@10.10.100.100'\n"
  puts "Password = vagrant"
  puts "-----"
  puts "Puppet modules brought in via puppet/Puppetfile are available on the Vagrant master VM at /etc/puppetlabs/puppet/modules"
  puts "-----"
  puts "Contact git owner for PR's & bug fixes"
  puts "-----"
  puts "Done."
end

desc 'Pull down modules in Puppetfile'
task :pull do
	confdir = Dir.pwd
	moduledir = "#{confdir}/puppet/modules"
	puppetfile = "#{confdir}/puppet/Puppetfile"
	puts "Pulling down new modules in #{puppetfile} to #{moduledir}"
	unless system("PUPPETFILE=#{puppetfile} PUPPETFILE_DIR=#{moduledir} /usr/bin/r10k puppetfile install")
		abort 'Failed to build out Puppet module directory. Exiting...'
	end
	puts "New modules successfully pulled down" 
end
desc 'Destroy Vagrant Machines'
task :destroy do
	puts "Are you sure you want to destroy the environment? [y/n]"
	STDOUT.flush
	ans = STDIN.gets.chomp
	if ans =~ /^y/
		system("vagrant destroy -f")
	else
		abort 'Aborting vagrant destroy, exiting...'
	end		
end
{% endcodeblock %}

[Entire project](https://github.com/malnick/puppet-module-devtest-skeleton/tree/malnick) is available on git.

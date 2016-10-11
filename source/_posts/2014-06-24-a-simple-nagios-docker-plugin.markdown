---
layout: post
title: "A Simple Nagios Docker Plugin"
date: 2014-06-24 12:19:43 -0700
comments: true
categories: 
---
Docker is an amazing tool with a lot great functional command line interfaces. A typical docker deployment might have a webapp running inside a container. In order to observe the beahvior of this container you might want to setup a Nagios plugin to monitor log output. 

To do this I am going to do the following:

1. Deploy an Ubuntu Precise VM on 10.10.33.2 via Vagrant
2. Provsion the VM with Puppet using the Vagrant Puppet provisioner:
	1. Installs docker using garethr-docker
	2. Installs the training/webapp image
	3. Runs the container using an exec
	4. Installs nagios and my ruby plugin to monitor the docker service and the training/webapp image for the following:
		1. Is the docker command available?
		2. Is the webapp running?
			- Ensures webapp is running on ```localhost:5000```
			- Checks the log for 404 errors and sends warnings if so
			- Counts the errors for each URL with a 404 and outputs the count and URL which has the highest hit count
			- test the above by trying ```10.10.33.2:5000/test``` over and over again

## The Vagrantfile
I start with a basic Vagrantfile to deploy an Ubuntu Precise VM:

{% codeblock %}
Vagrant.configure("2") do |config|
config.vm.provider "virtualbox" do |v|
	v.customize ["modifyvm", :id, "--memory", 1024]
end

config.vm.define :nagios do |deploy|
	deploy.vm.box = "precise64"
	deploy.vm.hostname = "nagios.server.dev"
	deploy.vm.box_url = "http://files.vagrantup.com/precise64.box"
	deploy.vm.synced_folder "modules", "/etc/puppet/modules"
	deploy.vm.synced_folder "manifests", "/etc/puppet/manifests"
	deploy.vm.network :private_network, ip: "10.10.33.2" # Define static IP once dev completes
	deploy.vm.provision :puppet, :module_path => "modules", :manifests_path => "manifests", :manifest_file => "deploy_nagios.pp"
   end
end
{% endcodeblock %}

## Puppet Provisioner
In order to provision the VM on boot I used the Puppet provisioner which ships with Vagrant. For testing purposes I like to sync my manifests and modules directory to the VM. Usually I run a bash script before provisioning with Puppet to install from the Puppet Labs apt or yum repos, however for this project that wasn't neccessary as the goal is to have a quickly bootable dev environment for my Nagios server and Docker container. 

The ```deploy_nagios.pp``` manifest looks like this:

{% codeblock %}



# Deploy docker and an Ubuntu image to play with
class {'docker':}
docker::image { 'training/webapp':
  require => Class['docker'],
}
# Super hero hack to run the docker image... see readme for why.
# Also, in no way is this idempotent, if it's running it'll fail.
exec { '/usr/bin/docker run -d -p 5000:5000 training/webapp python app.py':
  require => Docker::Image['training/webapp'],
}
#docker::run { 'webapp':
#  image   => 'ubuntu',
#  command => '/bin/echo test',
#  require => Docker::Image['training/webapp'],
#}

# Update this thing
exec { '/usr/bin/apt-get update':}

# Install nagios 
class { 'nagios': 
  require => [Exec['/usr/bin/apt-get update'],Class['docker']]
}

# Get my plugin on the system correctly
nagios::plugin { 'docker_status':
   source => 'nagios/nagios-plugins/docker_status.rb'
}

# WARNING: TOTAL HACK PLEASE DON'T JUDGE ME
exec { '/bin/echo "command[docker_status]=/usr/lib/nagios/plugins/docker_status" >> /etc/nagios/nrpe.cfg':
  require => File['/etc/nagios/nrpe.cfg'],
  notify => Service['nrpe'],
}

# Ensure docker and nagios are in the same group
exec {'/usr/sbin/usermod -a -G docker nagios':
  require => Class['nagios'],
  notify  => Service['nrpe'],
}

nagios::command { 'docker_status':
  command_line => '$USER1$/check_nrpe -H $HOSTADDRESS$ -c docker_status',
}

# Set the nagiosadmin password 
exec { '/usr/bin/htpasswd -cb /etc/nagios3/htpasswd.users nagiosadmin nagiosadmin': 
  require => Class['nagios'],
}

# I wrote my plugin in Ruby so lets make sure the VM has it. 
package { 'ruby1.9.1':
  ensure => present,
  require => Class['nagios'],
}

{% endcodeblock %}


Yup, I had a couple of hero hacks in there to get around some issues with the ```docker::run``` define. That define should work, but  kept failing with a very odd '<< is not a {}:hash' error. I grep'ed through the module to try and find where this was coming from and I think it's a heredoc within a function for the define. I still need to look into it. I ran an exec after the image is downloaded to get around this problem.

I also hero hacked the update to the ```nrpe.cfg``` file as the Nagios module I used didn't make it clearly evident how or if it did this. 

... In no way do any of these hacks make me an "inpatient" person. 

## The Nagios Plugin
Recall my plugin should monitor: 

1. Is the docker command available?
2. Is the webapp running?
	- Ensures webapp is running on ```localhost:5000```
	- Checks the log for 404 errors and sends warnings if so
	- Counts the errors for each URL with a 404 and outputs the count and URL which has the highest hit count
	- test the above by trying ```10.10.33.2:5000/test``` over and over again

### Let's break it down 

#### Nagios Basics:
First, let's define some basic outputs for the Nagios API. Since Nagios is only looking for specific exit codes from any given script we define those as methods here first. 

	0 = OK
	1 = Shit is potentially hitting the fan
	2 = Shit is hitting the fan
	3 = Unknown shit is happening

#### The first part of my Plugin defines these:

{% codeblock %}
#!/usr/bin/ruby
# Checks the docker status command for number of running containers
# Ensures the docker container is running by checking that the socket exists
# 

# Define some helper methods for Nagios with appropriate exit codes
def ok(message)
	puts "OK - #{message}"
	exit 0
end

def critical(message)
	puts "Critical - #{message}"
	exit 2
end

def warning(message)
	puts "Warning - #{message}"
	exit 1
end

def unknown(message)
	puts "Unknown - #{message}"
	exit 3
end
{% endcodeblock %}

#### Check to ensure docker is installed
Now let's check to ensure Docker is installed, we can use a simple ```system()``` method which returns exit codes only:

{% codeblock %}
def docker_installed()
	if system("which docker > /dev/null")
		webapp_status()
	else
		critical("Docker isn't installed")
	end
end
{% endcodeblock %}

Yup, it's that easy, ```which docker``` will return '0' or 'false' if it does not find the command and '1' or 'true' if a path to the command is found. This isn't the most robust check ever, but for now it's enough to move on. Since all my other def's work on the ```docker``` face and it's sub commands I need to ensure this is present before doing anything else. 

#### Check the webapp status
First, I want to make sure the webapp is running on the VM on a specific port. I'm going to use a ```netstat``` command and ```awk``` to return the process running on port 5000:

{% codeblock %}
def webapp_status()
	# Ensure the webapp is running on localhost:5000
	webapp_run = `netstat -anp | grep 5000 | awk '{print $7}' | cut -d/ -f2`
	should_be   = "docker"
	webapp_run.chomp!.strip!
{% endcodeblock %}

This should return this this: 

{% codeblock %}
root@nagios:/home/vagrant# netstat -anp | grep 5000 | awk '{print $7}' | cut -d/ -f2
docker
{% endcodeblock %}

Then we pass this into some basic 'if' logic:
{% codeblock %}
	if webapp_run == should_be
		# Check to ensure there are no 404 errors in the log
		check_this = "docker logs $(docker ps -l | awk '{print $1}' | awk '{if (NR == 2){print $0}}') 2>&1 | grep 404 | awk '{print $7}' | sort | uniq -c"
		check = system(check_this)
		if check 
			IO.popen(check_this) do |io|
				line  = io.readlines
				errors = {} 
				line.each do |this|
					number = this.split(' ').first
					url = this.split(' ').last
					errors.store(url, number)	
				end	
				max_value = errors.values.max
				max_key = errors.select { |k,v| v==max_value }.keys	
				case max_value.to_i > 20  
					when false  
						warning("#{max_value} 404 Errors at localhost#{max_key}")
					when true 
						critical("#{max_value} 404 Errors at localhost#{max_key}")
				end
			end	
{% endcodeblock %}

Lot's of things are happening there.

1st, if 'docker' is the output of the webapp status command we drop into another loop. This loop runs a ```check_this``` command that is derived from the ```docker log``` face. That particular face feeds the output from a sys-log-like to the terminals stdin.

But first, ```docker logs``` needs to have the process hash of the container you want to query, so I run a ```docker ps -l``` and ```awk``` for the hash of the process I want. 

{% codeblock %}
root@nagios:/home/vagrant# docker ps -l
CONTAINER ID        IMAGE                    COMMAND             CREATED             STATUS              PORTS                    NAMES
c968cced9f32        training/webapp:latest   python app.py       33 minutes ago      Up 33 minutes       0.0.0.0:5000->5000/tcp   berserk_pare
{% endcodeblock %}

This would definitely break if you had many containers running. 

So anyways, if we have that hash we can now pass it to ```docker logs``` like I did in the ruby script like this:

{% codeblock %}
root@nagios:/home/vagrant# docker logs c968cced9f32
 * Running on http://0.0.0.0:5000/
{% endcodeblock %}

Tight. 

Now that I have access to the log from the webapp I can grep URL's which have 404 errors, add those to a hash as k,v's and then iterate over the hash for the key with the largest value. 

{% codeblock %}
IO.popen(check_this) do |io|
	line  = io.readlines
	errors = {} 
	line.each do |this|
		number = this.split(' ').first
		url = this.split(' ').last
		errors.store(url, number)	
	end	
	max_value = errors.values.max
	max_key = errors.select { |k,v| v==max_value }.keys	
{% endcodeblock %}

Now I can use that key's value to hit my ```warning``` or ```critical``` methods.

{% codeblock %}
case max_value.to_i > 20  
when false  
	warning("#{max_value} 404 Errors at localhost#{max_key}")
when true 
	critical("#{max_value} 404 Errors at localhost#{max_key}")
end
{% endcodeblock %}

Of course, the end to this giant loop of loops does...

{% codeblock %}
		else
			ok("Docker & Webapp are in good shape!")
		end
	else
		critical("Webapp is not running on localhost:5000")
	end
end
{% endcodeblock %}

... and finally start it

{% codeblock %}
docker_installed()
{% endcodeblock %}
	
My entire script looks like this:
{% codeblock %}
# Full 
#!/usr/bin/ruby
# Checks the docker status command for number of running containers
# Ensures the docker container is running by checking that the socket exists
# 

# Define some helper methods for Nagios with appropriate exit codes
def ok(message)
	puts "OK - #{message}"
	exit 0
end

def critical(message)
	puts "Critical - #{message}"
	exit 2
end

def warning(message)
	puts "Warning - #{message}"
	exit 1
end

def unknown(message)
	puts "Unknown - #{message}"
	exit 3
end

# Check to ensure docker is installed
def docker_installed()
	if system("which docker > /dev/null")
		webapp_status()
	else
		critical("Docker isn't installed")
	end
end

def webapp_status()
	# Ensure the webapp is running on localhost:5000
	webapp_run = `netstat -anp | grep 5000 | awk '{print $7}' | cut -d/ -f2`
	should_be   = "docker"
	webapp_run.chomp!.strip!
	if webapp_run == should_be
		# Check to ensure there are no 404 errors in the log
		check_this = "docker logs $(docker ps -l | awk '{print $1}' | awk '{if (NR == 2){print $0}}') 2>&1 | grep 404 | awk '{print $7}' | sort | uniq -c"
		check = system(check_this)
		if check 
			IO.popen(check_this) do |io|
				line  = io.readlines
				errors = {} 
				line.each do |this|
					number = this.split(' ').first
					url = this.split(' ').last
					errors.store(url, number)	
				end	
				max_value = errors.values.max
				max_key = errors.select { |k,v| v==max_value }.keys	
				case max_value.to_i > 20  
					when false  
						warning("#{max_value} 404 Errors at localhost#{max_key}")
					when true 
						critical("#{max_value} 404 Errors at localhost#{max_key}")
				end
			end	
		else
			ok("Docker & Webapp are in good shape!")
		end
	else
		critical("Webapp is not running on localhost:5000")
	end
end

docker_installed()
{% endcodeblock %}
	

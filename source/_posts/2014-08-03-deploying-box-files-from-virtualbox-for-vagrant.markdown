---
layout: post
title: "Deploying .box Files from VirtualBox for Vagrant"
date: 2014-08-03 17:22:54 -0700
comments: true
categories: 
---
There are several tools available that streamline the production of the .box format for Vagrant from any open virtualization format (OVF). 

1. [Packer](www.packer.io)
Enables you to boot a given image from an easy to build template. You can provision the machine using many types of configuration management tools such as Puppet and Chef, and run post-installer scritps for anything else. 

The Templates are easy to use and you can push out a .box file from Packer directly. 

2. [Veewee](https://github.com/jedi4ever/veewee) 
Easily converts an ISO to VM formats. Kinda like Packer but not, so Packer made [this](http://www.packer.io/docs/templates/veewee-to-packer.html) tool to solve that problem.

## My own tool
Jeff, why would you ever build your own tool when so many others exist? Because I hate troubleshooting other peoples tools. If you've ever used Packer for anything serious, you could empathize/understand why I want to build my own tool. 

What do I want to do? 

1. Easily turn any VirtualBox registered VM on my host machine into a .box file and add it to Vagrant.
2. Deploy it in 1 command. 

## Architecture
A Rakefile that calls to sub .task files in a subdir to create then build out the machine. 

The top level Rakefile will allocate class variables such as directory strucutre, arrays and hashes used by the lower .task files. It will allocate ENV variables, in particular ```VM_USER``` and ```VM_PASSWORD``` to be used by the lower .tasks. It will also ensure all environment dependencies such as gems and programs are installed properly. 

## Rakefile
We'll start with the top level Rakefile and work our way down:

```ruby

begin
	require 'rake'
	require 'expect'
	require 'net/ssh'
rescue LoadError => e 
	puts "Error during load, running bundler"
	system('bundler')
end

# Load the subtasks
Dir['tasks/*.rake'].each { |file| load(file) }

# Set top level dir for sub level rake tasks
@cwd = File.dirname(__FILE__)

# Ensure we have some deps
gems = %w(net-ssh)
gems.each {|g| 
	unless system("gem list --local -q --no-versions --no-details #{g} | egrep '^#{g}$' > /dev/null 2>&1") 
		puts "#{g} gem not found, installing..."
		unless system("gem install #{g}")
			abort "Failed to install gem: #{g}"
		end
	end
}
exec = %w(vboxmanage)
exec.each {|p|
	unless system("which #{p}")
		abort "Failed to find the executable '#{p}', please make sure it's installed."
	end
}

namespace :vm do
	Rake::Task['create'].execute
	Rake::Task['build'].execute
end
```

The comments are self explanitory. We do some basic enviro checks, declare some class variables and load up the subtask files. 

Since this is *my* tool I can do whatever I want. This is going to be a super streamlined process, I only need it to work with VirtualBox so I don't need to get too crazy. I can basically rely on the ```vboxmanage``` command line tool to interact with the VM. 

***DISCLAIMER:*** I originally was going to leverage the [Net::SSH](http://net-ssh.github.io) ruby library to run all my post-processing on the VM. I needed some way to SCP scripts to the VM and execute them. Originally I used ```vboxmanage``` to get the IP address of the VM, then ```Net::SSH``` to SCP and execute commands. I had some methods all worked out for this, but then I ralized this needed to work on the VirtualBox NAT'ed network. 

Ouch. 

It would not reliably get a proper IP address and I also needed to do some fancy reverse SSH tunneling to SCP and execute with ```Net::SSH```. I struggled with this for an hour or two and realized my desire to use all Ruby libs to do this interaction was going to be more trouble than it was worth. I instead decided to use the ```vboxmanage``` subset of tools that will actually copy data to the VM and execute the data. I re-wrote my copy and execute methods but still kept the [Net::SSH code for later reference](https://github.com/malnick/create-vagrant-box/blob/master/extras/netssh_test.rb) since it's super handy. 

## Create 

```ruby

#!/bin/ruby
require 'rake'
require 'expect'
require 'net/ssh'

desc 'Build a Vagrant box from a vBox VM'
task :create do 
	# Vars 
	@vmhash 	= {}
	@vmname 	= ENV['VM_NAME'] 
	@vmuser 	= ENV['VM_USER']
	@vmpwd  	= ENV['VM_PWD']
	guestiso	= '4.3.8'

	# Get the guest edition ISO
	vboxexists = File.exists?("#{@cwd}/VBoxGuestAdditions_#{guestiso}.iso")
	if ! vboxexists
		puts "Would you like to install the defualt version of guest editions? [#{guestiso}] [y/n]"
		installdefault = STDIN.gets
		if installdefault =~ /^y/		
			puts "Ok, downloading vBox guest editions version #{guestiso}"
			unless system("wget http://download.virtualbox.org/virtualbox/4.3.8/VBoxGuestAdditions_#{guestiso}.iso")
				puts "Something broke downloading the guest editions iso."
				puts 'This may break the building of the box later, continue? [y/n]'
				cont = STDIN.gets
				if cont =~/^n/
					abort 'Aborting.'
				end
			end
		else
			puts "Which version would you like to use? [x.x.x]"
			installversion = STDIN.gets
			puts "Ok, downloading vBox guest edition version #{installversion}"
			unless system("wget http://download.virtualbox.org/virtualbox/4.3.8/VBoxGuestAdditions_#{installversion}.iso")
					puts "Something broke downloading http://download.virtualbox.org/virtualbox/4.3.8/VBoxGuestAdditions_#{installversion}.iso"
				puts 'This may break the buidling of the box later, continue? [y/n]'
				cont = STDIN.gets
				if cont =~ /^n/
					abort "Aborting."
				end
			end
		end
	end

		# Create a hash of vBox VMs
		num = 0
		vms = IO.popen('vboxmanage list vms')
		vms.readlines.each do |name| 
			@vmhash.store(num,name.split(" ").first.chomp('"').reverse.chomp('"').reverse)
			num=num+1
		end

		# how many vm's do we have available?
		@vmhash.each_with_index {|k,i|
			if i == @vmhash.length - 1 
				@vmmax = i 
			end
		}

		# Method to find if VM_NAME matches our hash listing
		def findvm()
			@vmhash.each do | k, v |  
				test = v.chomp('"').reverse.chomp('"').reverse
				return v if @vmname =~ /test/ 
			end
			nil
		end		

		# If a VM_NAME was given, don't list them but check to make sure it's a good name
		if ! @vmname
			puts "Which vBox VM would you like to vagrantize? [1-#{@vmmax}]"
			@vmhash.each {|k,v| puts "#{k}: #{v}\n"}
			vmcreate = STDIN.gets.chomp.to_i
			vmax = @vmmax
			until vmcreate.between?(0, vmax.to_i)
				puts "Range check"
				puts "Please select an integer between 1 and #{@vmmax}" 
				vmcreate = STDIN.gets.chomp.to_i
			end

			@vmname = @vmhash[vmcreate]
			Rake::Task['build'].execute
		else
			if findvm
				@vmname = findvm
				puts "#{@vmname} found with actual name: #{vmname}"
				Rake::Task['build'].execute
			else
				puts "#{@vmname} not found, available vm's for building are:"
				@vmhash.each {|k,v| puts "#{k}: #{v}\n"}
				puts "Which VM would you like to use? [1-#{@vmmax}]"
				vmcreate = STDIN.gets.chomp.to_i
				vmax = @vmmax
				until vmcreate.between?(0, vmax.to_i)
					puts "Please select an integer between 1 and #{@vmmax}" 
					vmcreate = STDIN.gets.chomp.to_i
				end
				@vmname = @vmhash[vmcreate]
				Rake::Task['build'].execute

			end
		end
	end
```

1. Check for vBox guest editions locally: I needed to make sure I had guest editions locally, if I didn't I would prompt to download the most recent release or give myself the option to install a different version. 

2. Get a list of all the registered VirtualBox VM's on the host: Get the list, create a hash that I can easily choose from with a numbered key.

3. Override the previous step if the ```VM_NAME``` ENV was given at runtime, ensure this matches with an actual VM registered in the list anyways.

4. Run ```Rake::Task['build'].excute`

## Build

```ruby
desc 'Build the vBox VM with Vagrant parameters'
task :build do
	def vmrunning? ()
		if system('vboxmanage list runningvms')
			runningvms = []
			vmproc = IO.popen('vboxmanage list runningvms > /dev/null')
			vmproc.readlines.each {|v| runningvms.push(v)}
			runningvms.each {|v| 
				if v =~ /"#{@vmname}"/
					puts "#{v} is running."
					true
				else
					puts "#{v} is not running."
					nil	
				end
			}
		else
			puts "No VMs are found running via [vboxmanage list runningvms]"
			exit 1			
		end
	end

	def vminfo()
		@vmdata = IO.popen("VBoxManage guestproperty enumerate #{@vmname}").readlines
	end

	def vmcp(locpath)
		unless system("vboxmanage guestcontrol #{@vmname} copyto #{locpath} /root/ --username #{@vmuser} --password #{@vmpwd} --domain 0755 --verbose")
			abort "Failed to copy #{locpath}"
		end
	end

	def vmexec(cmd)
		unless system("vboxmanage guestcontrol #{@vmname} exec --image #{cmd} --username #{@vmuser} --password #{@vmpwd} --verbose --wait-stdout")
			abort "Failed to run #{cmd} on guest machine"
		end
		puts "Successfully executed #{cmd}"
	end
	
	def vmexec_with_args(cmd, args)
		unless system("vboxmanage guestcontrol #{@vmname} exec --image #{cmd} --username #{@vmuser} --password #{@vmpwd} --verbose --wait-stdout -- #{args}")
			abort "Failed to run #{cmd} on guest machine"
		end
		puts "Successfully executed #{cmd}"
	end


	puts "-----"
	puts "Vagrantizing #{@vmname}"
	
	# Start the VM
	start = IO.popen("vboxmanage startvm #{@vmname}")
	@proc_id = start.pid
	puts "Process ID for VM: #{@proc_id}"

	puts "Waiting to bring up machine..."
	sleep(10)

	# The main loop
	while vmrunning?
		# Get VM IP Address
		vminfo.each {|line|
			if line =~ /IP/
				arry = line.split(",")
				@vmip = arry[1].split(" ").last.strip.chomp
			end
		}

		puts "Waiting for VM to become ready..."
		sleep(10)

		# Copy scripts dir to a locally accessible place
		scripts = Dir["#{@cwd}/scripts/*.sh"] 
		puts "Script dir: #{scripts}"
		scripts.each {|s|
			puts "Copying #{s} to VM..."
			vmcp(s)
		}
		
		geiso = Dir["#{@cwd}/*.iso"]

		# Copy guest editions over
		geiso.each {|iso| 
			puts "Copying #{iso} to VM..."
			unless system("vboxmanage guestcontrol #{@vmname} copyto #{iso} /root/ --username #{@vmuser} --password #{@vmpwd} --domain 0755 --verbose")
				abort "Failed to copy #{iso}"
			end
		}

	 	vmexec_with_args("/bin/chmod", "0755 /root/vagrant.sh")	
		vmexec_with_args("/bin/chmod", "0755 /root/vboxguest.sh")	
		vmexec_with_args("/bin/chmod", "0755 /root/compact.sh")	
		vmexec('/root/vagrant.sh')
		vmexec('/root/vboxguest.sh')
		vmexec('/root/compact.sh')

		# 
		unless system("vboxmanage controlvm #{@vmname} poweroff")
			abort 'Failed to shutdown vm'
		end

		puts "Waiting for VM to shutdown."
		sleep(5)

		puts "Packing vm..."
		unless system("vagrant package --base #{@vmname}")
			      abort "Failed to package the vm."
		end

		puts "All done."
		puts "-----"
		puts "VM package available at:"
		puts "#{@cwd}/package.box"
		exit 0
		#Process.kill(@proc_id) and exit 0
	end

	# Package the box up
	# vagrant package --output centos-6.5-x86_64.box --base centos-6.5-x86_64 <-- example.
end
```

So, that first method is what I'm going to wrap this entire program in - as long as the VM is running, lets copy some scripts to it, ensure they can be executed, then execute them.

### vmrunning?()

```ruby
def vmrunning? ()
	if system('vboxmanage list runningvms')
		runningvms = []
		vmproc = IO.popen('vboxmanage list runningvms > /dev/null')
		vmproc.readlines.each {|v| runningvms.push(v)}
		runningvms.each {|v|
			if v =~ /"#{@vmname}"/
				puts "#{v} is running."
				true
			else
				puts "#{v} is not running."

			end
		}
	else
		puts "No VMs are found running via [vboxmanage list runningvms]"
		exit 1          
	end
end
```

Pop open a vboxmanage process to list out the running VM's, ensure our VM exists there. 


### vminfo()

```ruby
def vminfo()
	@vmdata = IO.popen("VBoxManage guestproperty enumerate #{@vmname}").readlines
end
```

Super simple, use vbox manage to get a listing of VM data using ```guestproperty enumerate```. I used the ```.readlines``` method so I could iterate it into an array easily. 

### vmcp(locpath) 

```ruby
def vmcp(locpath)
	unless system("vboxmanage guestcontrol #{@vmname} copyto #{locpath} /root/ --username #{@vmuser} --password #{@vmpwd} --domain 0755 --verbose")
		abort "Failed to copy #{locpath}"
	end
end
```

Use the guestcontrol command for vboxmanage to copy stuff from my host to the guest. Copies it to ```/root``` by default. 

### vmexec(cmd)

```ruby
def vmexec(cmd)
	unless system("vboxmanage guestcontrol #{@vmname} exec --image #{cmd} --username #{@vmuser} --password #{@vmpwd} --verbose --wait-stdout")
		abort "Failed to run #{cmd} on guest machine"
	end
	puts "Successfully executed #{cmd}"
end
```

Execute commands without arguments on the guest VM. Handy for running my scripts after I copy them over or changing file permissions. 

### vmexec_with_args(cmd, args)

```ruby
def vmexec_with_args(cmd, args)
	unless system("vboxmanage guestcontrol #{@vmname} exec --image #{cmd} --username #{@vmuser} --password #{@vmpwd} --verbose --wait-stdout -- #{args}")
		abort "Failed to run #{cmd} on guest machine"
	end
	puts "Successfully executed #{cmd}"
end
```

Do the exec with arguments if needed. 

## Execute some scripts on the VM, exit, package the .box
The rest of the script is pretty straight forward. I drop into my ```unless vmrunning?()``` loop, copy over my scripts, run some ```chmod``` commands and execute them.

The scripts setup the Vagrant user and environmnent then install vBox Guest Editions and shutdown the VM once the scripts complete. 

Then it's simply a matter of using the ```vagrant package --base``` command on the box ***with the correct box timecode attached to it***. (that last bit is completely undocumented).

## Complete Project
[Available Here](https://github.com/malnick/create-vagrant-box/)

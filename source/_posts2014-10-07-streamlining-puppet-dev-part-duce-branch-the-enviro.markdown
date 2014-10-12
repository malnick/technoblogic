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


---
layout: post
title: "How To Install Rspec-Puppet on Puppet Enterprise"
date: 2014-03-20 09:42:50 -0700
comments: true
categories: 
---
If you're getting into rspec testing for your manifests you might already know this:  Puppet Enterprise has it's own gem environment. This is a quick post on how to install rspec-puppet to your PE gem environment.  

If you're new to rspec-puppet check out [this great site](www.rspec-puppet.com) for a brief on installing (except if you're on PE, then follow the install below). rspec-puppet.com also has a great tutorial to get your up and running.

### Installing rspec-puppet on Puppet Enterprise

If you've already installed rspec-puppet via system gem you will get this error on rspec-puppet-init:

	[root@master users]# rspec-puppet-init 
	/usr/lib/ruby/site_ruby/1.8/rubygems/custom_require.rb:31:in `gem_original_require': no such file to load -- puppet (LoadError)

If you've already installed rspec-puppet vis system gem:

	$ /usr/bin/gem uninstall rspec-puppet
	
Once system rspec-puppet is removed:
	
	$ /opt/puppet/bin/gem install rspec-puppet

Then to init a new puppet rspec enviro in your $moduledir:

	$ /opt/puppet/bin/rspec-puppet-init

This should build:

	+ spec/
 	+ spec/classes/
 	+ spec/defines/
 	+ spec/functions/
 	+ spec/hosts/
 	+ spec/fixtures/
 	+ spec/fixtures/manifests/
 	+ spec/fixtures/modules/
 	+ spec/fixtures/modules/users/
 	+ spec/fixtures/manifests/site.pp
 	+ spec/fixtures/modules/users/manifests
 	+ spec/fixtures/modules/users/lib
 	+ spec/spec_helper.rb
	+ Rakefile

### Installing PE-Specific Gems using PE-Gem Provider

[puppetlabs/pe_gem](https://github.com/puppetlabs/puppetlabs-pe_gem) has the provider for pe_gem so you can simply:

	package { 'json':
 		ensure   => present,
  		provider => pe_gem,
		}

That's it! 

---
layout: post
title: "Puppet Types: Understanding Parameters and Properties"
date: 2014-04-19 08:30:28 -0700
comments: true
categories: 
---
When starting out with Types and Providers for Puppet it's common to misunderstand when something is a *Parameter* and when something is a *Property*.

###**Properties**
Properties are anything that will **modify** a resource. In other words, attributes of a type that will change how that resource type exists on your system. A property is a charactaristic of a resource. A property does not change what a resource is, which is where the confusion usually begins. 

For example, let's take the file resource (anyone who has had the opportunity of taking Extending Puppet for Developers might find this redundant). 

	file {'/tmp/test':
		ensure	 => file,
		path	 => '/tmp/test', # $namevar
		owner	 => 'root',
		group	 => 'root',
		checksum => 'md5',
		content	 => 'foo',
		}

Any ideas which attributes are parameters and which are properties? Let's start with 

	ensure => file,

The 'ensure' attribute is actually created by the 'ensurable' method from the Puppet::Type class. Any attribute calling 'ensurable' gets the default 'present'and 'absent' values telling the type to call from the provider 'exists?()' then based on output from 'exists?' evaluates 'creates()' or 'destroy()'. 

Ensure modifies the resource, but does not change the definition of what that resource is to the system, therefore ensure is a property.

Other properties of file are

	owner
	group
	content

Content? Yes, content. On a file system the content of the file does not define the file, the *$path* to the file is the definition of a file. Therefore content is just a charactaristic of that file, making that attribute a property as well.



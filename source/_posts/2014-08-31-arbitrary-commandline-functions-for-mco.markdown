---
layout: post
title: "Arbitrary Commandline Functions for MCO"
date: 2014-08-31 08:16:59 -0700
comments: true
categories: 
---
mCollective is a funny tool. The idea behind it is obvious and great: a message bus for node orchestration. But the API and underpinnings are often a black box for many Puppet noobs and even other automation professionals. They mostly stick to the Puppet Enterprise Live Management console to interact with the mCollective back-end, never ```su peadmin``` and running a few ```mco $some_application -F $some_fact```. 

The truth is, MCO is a powerful backend for orchestration. It gets a bad name because the performance isn't there sometimes, especially at scale. Not to dive into a rabbit hole, but that's often due to user error: 1 broker running over 1000's of nodes; the ActiveMQ JVM being improperly tuned; bad layer 1  (yup, it can be that simple). 

One thing about MCO that is true is the API is hard to get through. It makes sense once you get under the hood, and especially after reading through other agents and DDl's but what if all you want is a simple way to run an arbitrary commandline argument on some remote node with MCO? If you don't know what you're doing that could take a while; if you know what you're doing, you still have the write the code.

Well, since MCO runs through an API we can actually architect templates for this exact task, for both the data description language file and the agent ruby script. 

Let's start with a basic DDL that will inform an agent running this arbitary command:

```
metadata :name        => '<%= @action_name %>',
         :description => '<%= @description %>',
         :author      => '<%= (@author_name+' '+ @author_email).strip %>',
         :license     => '<%= @license %>',
         :version     => '<%= @version %>', 
         :url         => '<%= @project_url %>',
         :timeout     => <%= @timeout %>

action "run", :description => '<%= @description %>' do
  display :always

  output :status,
         :description => "The exit code of the script",
         :display_as  => "Return Value"

  output :out,
         :description => "The output of the script on stdout",
         :display_as  => "Output Channel"

  output :err,
         :description => "The output of the script on stderr",
         :display_as  => "Error Channel"

end
```

Just a quick shout out to Jeremy Adams who wrote [this](https://forge.puppetlabs.com/jpadams/runyer) very ERB template for his Runyer module which does what this rake task does but in Puppet code.

So we've templated out the basic DDL for the agent. We've included some metadata and output - arbitary commands usually just need to be ran without input, for instance ```df -h``` and returns the mounted volumes and data about them. That could be handy in orchestration. If we wanted to we could add some inputs here, for example, if we wanted to pass in an arbitrary input to a command. I'm not interested in that here, just basic output from a command. 

Let's build out the ruby script to run this command:

```
module MCollective
  module Agent
    class <%= @action_name.capitalize %><RPC::Agent
      activate_when do
        <%= @activate_condition %> 
      end

      action "run" do
        command = '<%= (@cmd_prefix+' '+@command).strip %>'
        reply[:status] = run(command,:stdout => :out, :stderr => :err, :chomp => true)
      end
    end
  end
end
```

Our arbitary command only has 1 action. It's that simple. We run the command and push our output to the ouputs in the command.

Now let's look at the Rakefile that actually runs this. For me, I store most of my Rakefiles as ```*.task``` in ```~/.rake``` so I can run them anywhere with ```rake -g ```:

```
# Rakefile to create MCO agents and associated DDL
# Author: Jeff Malnick

def get_agent_template()
	template = File.read("rb.erb")
end

def get_ddl_template()
	template = File.read("ddl.erb")
end

class McoAgent
	require 'erb'
	attr_accessor :command, :template

	def initialize(template, command)
		@command 		= command
		@template 		= template
		@action_name		= command.split(" ").first
		@cmd_prefix		= ''
		@activate_condition 	= false
		@author_name  		= 'anonymous'
		@author_email 		= 'anonym@us'
	        @license      		= 'Apache v2'
		@version      		= '1.0'
	        @project_url  		= 'http://www.puppetlabs.com'
		@timeout      		= 15
	end

	def render()
		ERB.new(@template).result(binding)
	end

	def save(file)
		File.open(file, "w+") do |f|
			f.write(render)
		end
	end
	
end

task :mco_cmd do 
	
	command = ENV['command']
	puts "Creating mco agent and data description file for #{command}"

	# Create Agent .rb File
	agent = McoAgent.new(get_agent_template, command)
	agent.save(File.join(Dir.pwd, "mco_agents", "#{command.split(" ").first}.rb")) 
	ddl = McoAgent.new(get_ddl_template, command)
	ddl.save(File.join(Dir.pwd, "mco_agents", "#{command.split(" ").first}.ddl")) 
	puts "Path to agent: ", File.join(Dir.pwd, "mco_agents", "#{command.split(" ").first}.rb")
	puts "Path to ddl: ", File.join(Dir.pwd, "mco_agents", "#{command.split(" ").first}.ddl")


end
```

As you can see, I wrote my Class into the Rakefile itself. It wasn't long and let me have some clarity, so there wasn't a need to break it out.

The McoAgent Class accepts two attributes, command and template. Pass it a command and a template, for me I have a couple of def's that do this for the agent and ddl respectavely, and it builds out the ERB for us. My init def just declares the variables that we want available to our templates and we're good to go - the rest is accomplished via the ERB library. 

The entire project repo is available [here](https://github.com/malnick/rake_tasks/tree/master/mco_create_agent)




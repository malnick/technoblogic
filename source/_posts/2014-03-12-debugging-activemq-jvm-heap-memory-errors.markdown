---
layout: post
title: "Debugging ActiveMQ JVM Heap Memory Errors"
date: 2014-03-12 21:08:06 -0700
comments: true
categories: 
---
## This just happened: 

{% codeblock %}
INFO   | jvm 1    | 2014/03/11 16:12:34 | Exception in thread "ActiveMQ BrokerService[ppm.prod.dc2.adpghs.com] Task-79" Exception in thread "ActiveMQ BrokerService[ppm.prod.dc2.adpghs.com] Task-101" Exception in thread "ActiveMQ BrokerService[ppm.prod.dc2.adpghs.com] Task-87" Exception in thread "ActiveMQ BrokerService[ppm.prod.dc2.adpghs.com] Task-30" Exception in thread "ActiveMQ BrokerService[ppm.prod.dc2.adpghs.com] Task-74" java.lang.OutOfMemoryError: unable to create new native thread
{% endcodeblock %}

Since this is on a production server you need to recreate it in a testing environment. Since I'm partial to vagrant I stand up 4 agent nodes and a master via pe-build vagrant plugin. My Vagrantfile looks something like this:

```
# -*- mode: ruby -*-
# vi: set ft=ruby :

# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  config.vm.box = "centos-64-x64-nocm"
  config.vm.box_url = "http://puppet-vagrant-boxes.puppetlabs.com/centos-64-x64-fusion503-nocm.box"

  config.pe_build.version       = '3.1.0'
  config.pe_build.download_root = 'https://s3.amazonaws.com/pe-builds/released'

## Master
  config.vm.define :master do |master|

    master.vm.provider :vmware_fusion do |v|
      v.vmx["memsize"]  = "4096"
      v.vmx["numvcpus"] = "4"
    end

    master.vm.network :private_network, ip: "10.10.100.100"

    master.vm.hostname = 'master.puppetlabs.vm'
    master.vm.provision :hosts

    master.vm.provision :pe_bootstrap do |pe|
      pe.role = :master
    end

    config.vm.provision "shell",
      inline: "service iptables stop"
  end

## agent 1
  config.vm.define :agent1 do |agent|

    agent.vm.provider :vmware_fusion
    agent.vm.network :private_network, ip: "10.10.100.111"

    agent.vm.hostname = 'agent1.puppetlabs.vm'
    agent.vm.provision :hosts

    agent.vm.provision :pe_bootstrap do |pe|
      pe.role   =  :agent
      pe.master = 'master.puppetlabs.vm'
    end
  end

## agent 2
  config.vm.define :agent2 do |agent|

    agent.vm.provider :vmware_fusion
    agent.vm.network :private_network, ip: "10.10.100.112"

    agent.vm.hostname = 'agent2.puppetlabs.vm'
    agent.vm.provision :hosts

    agent.vm.provision :pe_bootstrap do |pe|
      pe.role   =  :agent
      pe.master = 'master.puppetlabs.vm'
    end
  end

## agent 3
  config.vm.define :agent3 do |agent|

    agent.vm.provider :vmware_fusion
    agent.vm.network :private_network, ip: "10.10.100.113"

    agent.vm.hostname = 'agent3.puppetlabs.vm'
    agent.vm.provision :hosts

    agent.vm.provision :pe_bootstrap do |pe|
      pe.role   =  :agent
      pe.master = 'master.puppetlabs.vm'
    end
  end

## agent 4
   config.vm.define :agent4 do |agent|

    agent.vm.provider :vmware_fusion do |v|
      v.vmx["memsize"]  = "1024"
      v.vmx["numvcpus"] = "2"
    end

    agent.vm.network :private_network, ip: "10.10.100.114"

    agent.vm.hostname = 'agent4.puppetlabs.vm'
    agent.vm.provision :hosts

    agent.vm.provision :pe_bootstrap do |pe|
      pe.role = :agent
      pe.master = 'master.puppetlabs.vm'
    end
  end
end
```

This error occured on an ActiveMQ install that works as the message que for a 1000 node deployment of puppet agents. To get terminology straight here, we have puppet agents and AMQ agents running on these 1000 nodes. They're all qued from a singular AMQ broker. 

My first impression was that this error may be caused by having 1000 agents pinging a single AMQ broker, which is limited to 800 via fds instances. 

I check locally on my test master:

{% codeblock %}
[root@master vagrant]# pgrep -f pe-activemq
1271
[root@master vagrant]# cat /proc/1271/limits | grep files
Max open files            1024                 4096                 files
{% endcodeblock %}

My soft limit is 1024 open files, and after rando .jars and logs and stuff that really feels like more around 800. So this is on the money, as far as what the docs say for ActiveMQ servers per broker. 

### How am I going to recreate what a 1000 node enviro looks like?

I'm limited to my laptop, 16GB of memory, and I'm too lazy to stand up 1000 instances in AWS (and to poor). So an attempt has to be made to recreate this memory error on my 5 nodes running locally. 

Given the above information, I start open a shell, and ssh into my master:

{% codeblock %}
[root@master vagrant]# echo -n "Max open files=3:3" > /proc/1271/limits
[root@master vagrant]# cat /proc/1271/limits | grep files
Max open files            3                    3                    files
{% endcodeblock %}

Why 3? Because:
{% codeblock %}
[root@master vagrant]# ls /proc/1271/fd | wc -l
6
{% endcodeblock %}

So a quick 'service pe-activemq restart' and bang...

Oh shit, new PID, new proc instance. Damnit. I have to figure out something else to fake the resource limits here. 

Since ulimit commands are shell-bound I can ssh into the master from another shell and run:
{% codeblock %}
[root@master vagrant]# ulimit -n 10
[root@master vagrant]# service pe-activemq restart
/etc/init.d/functions: redirection error: cannot duplicate fd: Invalid argument
Stopping pe-activemq:                                      [  OK  ]
Starting pe-activemq:                                      [  OK  ]
{% endcodeblock %}

The trick here is getting close enough to the lowest possible resource limits with out getting the
{% codeblock %}
bash: start_pipeline: pgrp pipe: Too many open files
/bin/sh: error while loading shared libraries: libtinfo.so.5: cannot open shared object file: Error 24
{% endcodeblock %}
error.

3 was actually too low, so I ran with 10 and was able to run a restart. You have to account for other files that may be bound to the PID instance, like logs and .jars since this is a bunch of java. And as everyone knows, Java is basically the pig of programming languages. 

So 10 fds worked and activemq has restarted. Let's look at my logs to see what I've got:

{% codeblock %}
INFO   | jvm 5    | 2014/03/13 04:46:13 | Error: Exception thrown by the agent : java.rmi.server.ExportException: Listen failed on port: 0; nested exception is:
INFO   | jvm 5    | 2014/03/13 04:46:13 | 	java.net.SocketException: Too many open files
{% endcodeblock %}

That isn't what I wanted to see. I am looking for heap memory errors. So this clearly demonstrates it's not an fds constraint at the filesystem level. Time to move on to other possibilities. 

### Possible Culprits

1. The JVM
	
	* Consider increasing the total heap memory available to the broker JVM
	* Consider reducing the default JVM stack size of each thread using -xss
	* If your broker is embedded ensure the hostiong JVM has appropriate heap and stack sizes. 

2. The broker

	* Broker memory is not JVM memory, it's only a constraint - the broker manages it's own memory. 
	* Setting appropriate systemUsage memory: http://activemq.apache.org/producer-flow-control.html#ProducerFlowControl-Systemusage
	* Hard limits exist on the number of agents a single broker can handle due to file descriptors and other hard system resources

###Solutions

Check your log for current JVM heap size:

	INFO   | jvm 1    | 2014/02/26 12:47:04 |   Heap sizes: current=506816k  free=487246k  max=506816k

Try bumping this up to 1GB in

	 /etc/puppetlabs/activemq/wrapper.conf

If you still get 

	INFO   | jvm 1    | 2014/02/26 12:47:38 | Exception in thread "ActiveMQBrokerService[ppm.prod.dc2.adpghs.com] Task-58" java.lang.OutOfMemoryError: unable to create new native thread 

in your

	/var/log/pe-activemq/wrapper.log

then throttle up your systemUsage in

	/etc/puppetlabs/activemq/activemq.xml

per [this guideline](http://activemq.apache.org/producer-flow-control.html#ProducerFlowControl-Systemusage)	

### Hard Limits of AMQ

If you still get OOM errors you may be at a hard limit for agents per broker. ActiveMQ uses the amqPersistenceAdapter by default for persistent messages. Unfortunately, this persistence adapter (as well as the kahaPersistenceAdapter) opens a file descriptor for each queue. When creating large numbers of queues, you'll quickly run into the limit for your OS.

However, your logs will not register a OOM error as above, they'll show

	ERROR  | wrapper  | 2014/03/13 03:32:39 | JVM exited while loading the application.
	INFO   | jvm 4    | 2014/03/13 03:32:39 | Error: Exception thrown by the agent : java.rmi.server.ExportException: Listen failed on port: 0; nested exception is:
	INFO   | jvm 4    | 2014/03/13 03:32:39 | java.net.SocketException: Too many open files

If that is your error your could try upping the limit on file descripters per process. You can do something similar to what I did above or [Google for your OS](http://tinyurl.com/o9qs2f).

At this point if none of the above resolved the issues you should try standing up a second broker, especially if you're running more than 1000 agents on a single broker instance. 

You can read more about [standing up networks of brokers](http://activemq.apache.org/networks-of-brokers.html) and also [AMQ performance](http://activemq.apache.org/performance.html). 

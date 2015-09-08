---
layout: post
title: "Static Service Provisioning Sucks"
date: 2015-07-14 13:05:01 -0700
comments: true
categories: 
---
Many tools exist to help automate and orchestrate provisioning servers. Each tool serves a purpose, or is tailored for a specific task. One realization I had not to long ago was that configuration management tools, as a framework, suck at provisioning micro services. I say that at the risk of bringing on the deluge of comments that often accompany such a blunt, over arching statement. 

<!-- more -->

## Configuration Management Primer
But let's think about it for a minute: how does configuration management work? The idea is to codify machine state into a static code base that can abstract a more complex system into simple resource statements. Then those resource statements are parsed and compiled into a [directed acyclic graph](https://en.wikipedia.org/wiki/Directed_acyclic_graph).  

This graph is created every time an 'agent' of some sort checks in or is manually kicked off by some other means. Each node in the graph represents the abstract state of some resource on the system, files, services, packages, and compares the state of the resource node in the graph to that of the resource which exists on the system. If it's different, it converges the state to match that of the graph. 

## Service Primer
In terms of services, we might have an abstract service definition that looks like this:

```ruby
service { 'haproxy':
  ensure => running,
}
```

or

```ruby
service 'nginx' do
  action :start
end
```

Each statement tells Puppet or Chef, respectively, to make sure the service for Nginx is running. How this would go down in real life is that Chef or Puppet would run, and if they find the service Nginx not running, it would be started. If it is found running, nothing occurs in order to maintain performance via idempotent actions. 

The problem is services are running all the time, and are highly dynamic. They might crash for any number of reasons, and until configuration management kicks in, your service is unavailable. 

That is, unless, it's monitored by a parent process that can track service state. 

And in a lot of respects, framworks such as Docker aim to fill in this hole. The Docker daemon acts as that parent process that can monitor the child containers, ensuring they're always running or force restarts when they die. The Docker daemon is always running, unlike configuration management which only runs on regular intervals, and hopefully not to often for performance reasons. 

Well what happens when the Docker daemon dies, you might ask? Who cares, it's still better than configuration management acting as the sole service schedular. 

Many people have already realized this added benefit of Docker monitoring their service state. In that same vain, containerizing your services via Docker removes a lot of configuration management code. Where previously you had to maintain a package, a file, a service and all the other dependencies around your specific service via configuration management you can now simply tell configuration management to install docker and run this container. 

## Static vs. Dynamic 
The hills rejoiced to the sound of sweet harmony of constantly running services! 

But this isn't the end of the story. Whether you're running your service via some executable you provision with configuration management or via a docker container executed via configuration management, those services are still statically provisioned. 

By static provisioning, I mean that you have some how hard coded a $role for a node classified as 'x' and told your configuration management system to run service 'y' for all machines with that classification. This is hard coded and static. The machine that runs this service does not change unless you hard code something else to tell it to do so. 

That might be acceptable for simple applications, but when scaled you run into another issue: resource utilization. 

At SRC:CLR we have a meager 70 node deployment. The resources of each node are unknown to other nodes, and we fall into the pitfall of underutilized infrastructure. We're not an enterprise, but recent studies show total DC utilization at [around 6%](https://gigaom.com/2013/11/30/the-sorry-state-of-server-utilization-and-the-impending-post-hypervisor-era/). We average around 1-2% total resource utilization. This tells me we're wasting at best 68% of our monthly DC costs (I would prefer 70% resource utilization, allowing for a comfortable 30% in over engineering for capacity).  

It's easy to fall into this pitfall if your entire stack is managed by a static code base - it's programmatically difficult to classify a node in configuration management with a lot of different roles. You would need to instrument each node heavily to ensure proper resource utilization, and go to great lengths to ensure you're not creating hot spots - machines that are running hot, consuming too many resources while others sit idle with low intensity applications. 
In the end, this is still a static configuration and is extraordinarily complex. 

Dynamic configuration, at its core, assumes some master process provisions a service on demand, anywhere. It's not bound by classification, its only requirement is that memory and CPU resources are available to execute a scheduled task. It monitors these processes all the time, ensuring they're running and restarts them when they die. 

This system sounds a lot like a Kernel in an operating system: it accepts IO to execute tasks and leverages a scheduler to execute those tasks across available memory and CPU resources. 

## Mesos 
The [Apache Mesos project](http://mesos.apache.org/) satisfies that requirement: it gathers resource information from all nodes in a cluster, then schedules and executes tasks against the available resources. An entire company, Mesosphere, has built the [Data Center Operating System](https://mesosphere.com/product/) around Mesos, allowing seamless deployment of services across a cluster of machines, without configuration management to statically deploy them. Developers can write their own schedulers and executors or simply leverage the Docker executor to deploy services across an entire DC. No classification required. 

At SRC:CLR we see the value in such a system as it simplifies our already complex configuration management around our back end micro services. This isn't to say configuration management isn't needed: it's needed. However, we've found that configuration management isn't a service scheduler - it's great at static provisioning. But in the end we still need a way to manage all the basics like log rotation, the installation of Mesos, docker and other necessary packages, and all the other stuff that sits outside the realm of our immediate stack but is required by it.  

Our goal for the future of our stack is to have Puppet manage the intermediate state of our infrastructure, bringing up a healthy cluster of nodes running Mesos which we can deploy our containerized stack on. Of course this brings about a whole new set of challenges around managing logs and security, topics I'll be covering more in later posts. In the end the move to leveraging a service that handles dynamic scheduling of our services allows us to scale faster while simultaneously using more available resources, which means a decrease in Ec2 instances and incurred costs. That's a huge win for a small company making ends meet on borrowed dollars.   

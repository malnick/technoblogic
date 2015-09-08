---
layout: post
title: "Factory Patterns: Rule #1"
date: 2015-04-15 10:32:31 -0700
comments: true
categories: 
---
# Factory Patterns
I learned early on in my career that the trick to successfully maintaining large, complicated deployments was to make things so that they are like a factory, then solve your problems using factory patterns. The metaphor is extended from the continuous integration pipelines I develop for seamless code deploys to the ways in which I go about maintaining the infrastructure on which that code runs. 

<!-- more -->

### Rule #1

Rule #1, the litmus test for your infrastructure: can you deploy your nodes into any cloud platform with out a SSH key and have your entire application up and running, zero intervention required? 

Rule #1 requires skillfully built configuration management code. It doesn’t matter what configuration management system you use as long as it satisfies the prerequisite that you can deploy your entire stack and never have to SSH into the box. 

Now I’d also add that the code you write which abstracts the configuration of any machine should be clear enough that any person who comes into your organization, either with you or after you leave, be able to understand the complete configuration of a machine by simply looking at your CM code, most notably the $role manifest or recipe.

This syntax-ual sugar isn’t required for Rule #1 to be successful but plays a key role in ensuring the agile process of CM doesn’t become the burden of every other systems engineer in your organization. Good configuration management code should be abstract enough that any developer in your organization can understand the deployment of their code based on a given $role and every systems & operations engineer can find clues as to where to look when things go astray by looking at that same CM code block. 

### The Pattern

A good factory is like a state machine, for a given input it produces a given output. Infrastructure is the same way, the inputs are straightforward: bare metal provisioning + configuration management + service discovery. These three inputs are generated in different ways but no matter what are always conceptually similar. 

#### Bare Metal
Regardless of if you’re deploying in vCenter, AWS, Heroku or DigitalOcean you have a concept of a VM / Instance / Dyno / Droplet. Each platform has it’s own way of managing the deployment of those pieces, but the end result is similar: abstracted bare metal provisioning. 

#### Configuration Management 
Once the bare metal piece is in place the next stop in the factory is configuration management. Chef, Puppet, Ansible, and others all share a common thread: abstract away the notion of “resources” on a machine ($package, $file, $service) regardless of operating system or deployment environment and be able to declare those resources in an easy to understand way. 

Puppet uses it’s own DSL for CM based on Ruby, Chef uses it’s own Ruby libraries, Salt uses the YAML interchange format as well as Ansible. The idea at this point in the factory is to implement a system that abstracts away how to provision a resource on a machine and instead simply require that resource exist in a specific way. 

So a user can be defined as:

```ruby
# Puppet
user { ‘jeff’: ensure => present } 

# Chef
user “jeff” do action :create end

# Ansible
- user: name=jeff
```

This abstraction enables the operations person to automate the deployment of resources to a given machine, in this example the user ‘jeff’, without having to worry about **how to provision** - the idea being, you don’t need to tell the computer how to make the user ‘jeff’, you simply declare it in your manifest/recipe/playbook and you’re done. 

Now this is an incredibly simple task, a single user. When you’re talking about tens of thousands of resources that may be compiled into a given catalogue to be processed on the node there are a lot of other considerations you have to take into account such as ensuring each step in the process is idempotent (you don’t execute a resource if the state of the machine already matches); ensuring the catalogue is a-cyclic (no resource dependencies create loops). 

At the end of the day this entire, highly complicated process, should be easily readable and understood at it’s highest layer of abstraction, i.e., some sort of role manifest/recipie that takes all those resources and wraps them into a value that conveys the business logic of what that code does.

```ruby
# Puppet
# $confdir/modules/role
class role::qa_haproxy_frontned { … }

# Chef
# ~/chef-repo/roles/qa_haproxy_frontend/role.rb
name “qa_haproxy_frontend”
description “The outer most layer of the QA Haproxy frontend CM code”
run_list ("recipe[qa_haproxy_frontend]”)
```

All things being equal the end goal is abstraction. The CM factory should make simple the increasingly complicated step of provisioning a node in a specific way. The code should be elegant, readable and maintainable. The output should be a working machine with a repeatably deployable state. 

#### Service Discovery
The last piece to the puzzle is service discovery. This piece, previously thought of as “optional” for most deployments is becoming more of  a main stay due to the design principles of service oriented architecture. SOA ensures we have many services to maintain, sometimes many instances of that service on a given node, each satisfying a specific feature of the application. In some ways SOA makes more simple the maintenance of the product, such as enabling developers to easily deploy code changes to a specific service which may not completely break the overall usability of the application if something goes wrong during a code change. 

From a systems engineering perspective it enables easier scaling in that you can scale a specific service rather than the entire monolithic code base to meet the demands of an increasing user base. However, how the scaling occurs is the complicated part of this final stop in the factory. Everything from assigning a port for the service process to listen on to ensuring the service actually exists and is healthy is complicated to say the least.

ZooKeeper, ETCd and other service discovery tools allow a single point of contact for each service to reach out to in order to feed those metrics back to a master process and in some cases do some basic configuration management based on information from those systems. However, these tools also ensure a single point of failure which is why ZooKeeper takes high availability seriously. The uptime of those service discovery tools also relies on other tools such as DNS or other hostname resolution mechanisms, thereby increasing not only the complexity of your deployment by one tool but rather by a number of tools. 

Implementing successful service discovery for your SOA is not for the faint of heart. More tools are coming out that bundle up ZooKeeper in a larger framework that abstracts these finer details. For example Mesosphere bundles the Mesos and Zookeeper projects with a distributed init and process management framework called Chronos and Marathon. Marathon can receive a POST with a specific docker image in a cloud or locally hosted registry along with information such as how many containers it needs to boot across your infrastructure. Mesosphere aims to abstract away the complicated task of port assignment and “is this service running” to ensure you alway have ’n’ number of services up, and if you need ’n’ more it makes it as easy as a POST or input via the web UI. 

Synapse and Nerve also serve a similar end goal: deploy service ‘x’ ’n’ number of times; ensure service ‘x’ is healthy, and if not, remove service ‘x’ from rotation and deploy another to replace it. Simple right? 

### In the end
In the end, Rule #1 still stands: can you deploy your entire application stack from bare metal to fully operational in one command and with out having to use SSH to get into a node? 

The final output of the factory should be your working web application. You should never have to SSH into any node: metrics and log data should be shipped off each node routinely using tools like Logstash and StatsD - SSH’ing because you needed to run ‘free -h’ or ‘tail ‘f /var/log/whatever.log’ isn’t scalable. Imagine running 10 services, each one dumping ‘docker logs’ to a /var/log/service_instance, across 100 nodes. Are you going to SSH into each one and tail? Fuck no. You’re going to need a consolidated place where each log gets turned into usable metrics for inspection via graphs or search. 

Same goes for metrics.

Your configuration management should provision these log and metric aggregation services at boot so they’re “just there” the next time you log into whatever system you use to aggregate this data. Sound logrotate policies should be in place to ensure you don’t blow up /var/log. Alerting mechanisms based on derived metrics should be in place to ensure when things do break and you **absolutely** have to SSH into that box with your dusty SSH key that you know exactly where to look and the alarm didn’t sound because the APM metric for the app was based on a hard limit. Limits are never hard, they’re derived from rolling averages, but that’s fodder for a future post. 




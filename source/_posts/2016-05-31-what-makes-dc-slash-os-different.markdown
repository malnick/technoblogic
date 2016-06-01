---
layout: post
title: "What Makes DC/OS Different"
date: 2016-05-31 17:41:07 -0700
comments: true
categories: 
---
True story: Every single day I'm posed with this question, what makes DC/OS different? What sets us apart from Kubernetes, Docker Swarm, Rancher and other schedulers that seemingly show up in the market every day? 

I could go into great detail about how amazing the company is (we are hiring!), or the ingenious vision of an "app store" for the data center. But what really sets DC/OS apart is two level scheduling. 

You can ask [Quora](https://www.quora.com/How-does-two-level-scheduling-work-in-Apache-Mesos), or [Opensource.com](https://opensource.com/business/14/9/open-source-datacenter-computing-apache-mesos), and of course good ol'fashioned [Stack Overflow](http://stackoverflow.com/questions/21953111/mesos-scheduling-how-this-works) but we'll deep dive on it here so you can really come to appreciate this overlooked feature of Mesos and of course DC/OS.

What if I told you that you can run Kubernetes on Mesos? Well, [you can](https://github.com/mesosphere/kubernetes-mesos). The magic that makes this possible is the two level scheduler. That means you can run your docker container that has your app on top of Mesos next to a Kubernetes cluster that has other things your app might want. Or, your organization as one developer who loves Docker and another who loves Kubernetes, they can both use the same infrastructure to run their development pipelines.

The two level scheduler allows you to abstract any application, and deploy it to a highly available, fault tolerant environment that reacts to fail over crashes in ways specific to your your application. This deployment mechanism is a `Framework` and is the second layer to the two level scheduler. When you write a framework for your application you provide Mesos with very fine grained details about how you want your application and Mesos to work together to ensure uptime and availablility of the service. This also means you can turn most modern applications into web frameworks, since there are bindings for [golang](https://github.com/mesos/mesos-go), [python](https://github.com/apache/mesos/tree/master/src/examples/python), Scala, and of course C++ (links on [the Mesosphere website](https://open.mesosphere.com/getting-started/resources/).

Under the framework is Mesos, which has a agent and master service. The agent tells the master what resources it has available (cpu, memory, disk), and the master makes these resources offers to the Frameworks which ask for them. If the resource offer is accepted by the Framework, the master schedules the Framework to run. 

A very popular framework is [Marathon](https://mesosphere.github.io/marathon/), which is a container orchestration engine that runs on Mesos. When I think of Docker Swarm or Kubernetes, I often compare them to Marathon, since at their essence, those tools do the same job: orchestrate the deployment of containers to a set of hosts in a cluster. 

And that's where the beauty of DC/OS lives: our ecosystem isn't just container orchestration, it's that plus application orchestration of almost any kind. Be it Python code, C++, Scala, Golang, you can write a framework and deploy it on Mesos next to other application, or orchestration engines providing other services. It's what allows us to make our one click deployments of [Cassandra](https://github.com/mesosphere/cassandra-mesos) or [Jenkins](https://mesosphere.com/velocity/) so bomb proof and dead simple. 

We abstract all the nuances of how the application should behave, from deployment to crashing to rehabilitiation so you can focus on what's important: making your own amazing product. DC/OS is simply a catalyst for your work. 

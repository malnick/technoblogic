---
layout: post
title: "Version Management in SOA"
date: 2015-08-13 08:47:19 -0700
comments: true
categories: 
---
Service oriented architectures offer significant increases in agile deployment pipelines. They allow what were traditionally, large, monolithic code bases to be broken down into smaller, more manageable pieces. Instead of diagnosing a single issue that affects the application as a whole, SOA allows developers to troubleshoot smaller, atomic pieces.

SOA, by design, goes hand-in-hand with the concept of immutable infrastructure: you can now deploy small pieces of your application, codifying the infrastructure it runs on along the way, allowing for easy to maintain, automated application layers. 

Commonly, this design pattern manifests itself with lots of small services proxied by some kind of layer 7 load balancer (nginx or haproxy) on the backend of some type of platform. The layer 7 load balancer allows easy to navigate REST API access. It also means the nodes which run these services have less overall configuration since they only need to run a small piece of the larger application, a single service. The natual evolution of this tends to be some kind of remote or dynamic service execution system that is agnostic of individual server resources, such as Apache Mesos. 

Of course, service discovery mechanisms in this type of immutable environment are key. 

## The Problem
Now we have many, scatter services. Each deployed onto ephemeral servers with ephemeral IP addresses. Assuming the continuous integration pipeline is "merge-to-environment", it's easy for developers to increment and deploy builds to QA or Production. 

But how do you track the service versions running on each node across several, ephemeral boxes? How do you know CI was successful and the version you wanted to deploy is in fact running across all instances of the servers which execute your specific service?

The classic way was to query your service's managment endpoint. The IP of the server running the service and the privately held management port. 

For the deployment at SRC:CLR, we managed a table of ports associated with services. Each service gets allotted 10 ports in a range, for each service and management port. This meant no more than 10 of each process could exist on a box together. It also means managing a port table. See [my rant about why this sucks](http://www.jeffmalnick.com/blog/2015/07/14/static-service-provisioning-sucks/).

## The Solution
Our solution to tracking versions agross all running boxes is [VersionCtl](https://github.com/malnick/go_vctl). 

VersionCtl is a go app that runs inside a docker container. It queries our Haproxies via [REST HaProxy](https://github.com/malnick/rest_haproxy), a service which reads out the haproxy config, and abstracts the backend blocks to "services" with endpoints (the server lines in the backend block). It exposes this as a rest endpoint which VersionCtl ingests. 

What this looks like in a deployed environment is this:

![img]()

If versions between nodes in a given backend service abstraction do not match, the service line in VersionCtl goes red. VersionCtl also queries our Puppet Master for the versions.yaml hiera configuration file. This file is managed by jenkins in that it's rewritten everytime a build occurs with the version from Maven which was just built. It does this via a REST endpoint on the Puppet Master. 

If the version running on a box does not match that of hte version in versions.yaml, the line will go red as well. This gives us fast visability into the state of a deployment, in real time. If the service failed to deploy onto a box, we know. If the CI pipeline broke between jenkins and the box, we know. 

VersionCtl also kicks back the response from the actual GET request, allowing us to quickly see how the service is responding to the first thing we'd do in the event of a CI or deployment malfunction: curl the management endpoint. 

## Homogenous Functionality
Eventually we'll want to roll out our Apache Mesos deployment. This will leverage Mesosphere's Marathon utility for deployments to the cluster. We could rewrite VersionCtl at that point, but since it's leveraging REST Haproxy we can actually continue to use it, adjusting the haproxy endpoints that it quaries. In combination with [Marathon Template](https://github.com/malnick/marathon_template.git), we can easily dynamically update VersionCtl as the infrastructure expands and contracts. With these three services we can scale out our infrastructure while maintaining visability into the running versions, keeping track of our dynamically updated environments and the deployments in real time. 

## Can I use this? 
Yes. VersionCtl is [open sourced](https://github.com/malnick/go_vctl) along with [REST HaProxy](https://github.com/malnick/rest_haproxy) and [Marathon Template](https://github.com/malnick/marathon_template.git). You'll have to modify the production version that we run since you probably don't have the same versions.yaml CI pipeline. You can do this by removing puppetversions() method and it's implementation in the compare() method. You'll also have to update the index.html GO template to remove the pv index.   

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

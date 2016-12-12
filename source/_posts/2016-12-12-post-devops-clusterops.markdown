---
layout: post
title: "Post-DevOps: ClusterOps"
date: 2016-12-12 09:11:09 -0800
comments: true
categories: 
---
In the post-DevOps land we've moved passed how to codify infrastructure as code, system administrators are squarely part of the development teams which they enable. In the ClusterOps world, we are building tools to enable companies to treat their systems as a single entity, orchestrating various container technologies across clusters in hybrid clouds, federating them together on a grand scale.

Many small start ups are seeing a great deal of benefit, enabling them to hire less people to manage complicated micro services platforms. On the enterprise scale, I'm seeing large companies benefit from federated clusters across hybrid clouds, allowing them to build complicated charge-back models to their internal teams and save costs by maximizing usability of their cloud-based infrastructure.

The new ClusterOps world is defined by orchestration tools we've come to know very well: [DC/OS](http://dcos.io), [Kubernetes](http://kubernetes.io), and [Docker Swarm](https://www.docker.com/products/docker-swarm). These tools allow simplified orchestration of services through various containerization technology and abstracting the complexity of managing many hosts into a single pool of resources. There are many words that folks use today to describe these tools, but nobody will deny that all look like one thing: an operating system. 

In a former world, we developed tools to enable system administrators to treat their infrastructure as code. This movement redefined the system administrator as a developer, automating large, complicated systems by defining their parts in cloud formation templates and automating up to layer 7 with ools like [ Puppet](http://puppet.com), Chef and Ansible. When cloud options were not available, we built our own with systems such as [OpenStack](https://www.redhat.com/en/insights/openstack). 

Entire companies were built around enabling companies to succeed i the DevOps space. Companies uch as s [RedHat](https://www.redhat.com) and countless other consultancies made bets on the tools available, and leveraged them to build offerings in their vision of"the right way". 

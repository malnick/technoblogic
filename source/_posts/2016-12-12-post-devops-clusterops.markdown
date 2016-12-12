---
layout: post
title: "ClusterOps is Post-DevOps"
date: 2016-12-12 09:11:09 -0800
comments: true
categories: 
---
In the new post-DevOps land we've moved passed how to codify infrastructure as code, system administrators are squarely part of the development teams which they enable. In the ClusterOps world, we are building tools to enable companies to treat their systems as a single entity, orchestrating various container technologies across clusters in hybrid clouds, federating them together on a grand scale.

Many small start ups are seeing a great deal of benefit, enabling them to hire less people to manage complicated micro services platforms. On the enterprise scale, I'm seeing large companies benefit from federated clusters across hybrid clouds, allowing them to build complicated charge-back models to their internal teams and save costs by maximizing usability of their cloud-based infrastructure.

The new ClusterOps world is defined by orchestration tools we've come to know very well: [DC/OS](http://dcos.io), [Kubernetes](http://kubernetes.io), and [Docker Swarm](https://www.docker.com/products/docker-swarm). These tools allow simplified orchestration of services through various containerization technology and abstracting the complexity of managing many hosts into a single pool of resources. There are many words that folks use today to describe these tools, but nobody will deny that all look like one thing: an operating system. 

In a former world, we developed tools to enable system administrators to treat their infrastructure as code. This movement redefined the system administrator as a developer. Automating large, complicated systems by defining their parts in cloud formation templates and automating up to layer 7 with tools like [ Puppet](http://puppet.com), Chef and Ansible. When cloud options were not available, we built our own with systems such as [OpenStack](https://www.redhat.com/en/insights/openstack). 

Entire companies were built around enabling companies to succeed in the DevOps space. Companies such as s [RedHat](https://www.redhat.com) and countless other consultancies made bets on the tools available, and leveraged them to build offerings in their vision of "the right way". 

Today, vendors in this space provide these tools overlapping features for free or with licensing. Some companies purchased the intellectual property to build them into an existing licensing model. What this conveys is that these tools were successful. So much so that companies are able to build a tidy profit from them by making them more accessible. 

In this way, those companies brought DevOps to the masses. No longer did you have to be that trick Sys Admin with code experience. Anyone could get a streamlined setup with bare metal through layer 7 automation, a fly continuous integration pipeline, top notch monitoring and infrastructure visibility, all for a price. 

This conveys that not only were these tools successful, the movement that brought them to the doorsteps of companies large and small was also a winning strategy. The DevOps movement won out over monolithic,  siloed engineering. 

ClusterOps is the next logical progression in this movement: 
***DevOps addressed managing singular resources with code; ClusterOps addresses the complicated relationships these resources have with each other.***

Tools such as DC/OS and Kubernetes allow us to treat many hosts as a singular entity. They take care of scheduling where, when and how many instances of a given service are running. They abstract away the notion of singular hosts, and replace them with a single point of contact for operators and developers. This single point of contact allow those professionals to treat these systems as a cluster; the interaction, development and operation of this pool of resources is ClusterOps. 

ClusterOps vendors are already popping up everywhere. With many consultancies and developer tool companies being built every day to enable their clients with this *new way*. Just as the success of DevOps was signified by a similar explosion of support and tools for infrastructure as code, the proliferation of companies and tools for cluster operations conveys a similar movement and success story. I'm very excited about this future for the infrastructure engineering space and am looking forward to seeing how it develops. 

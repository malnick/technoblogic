---
layout: post
title: "Autoscaling Configuration Management"
date: 2014-03-16 15:07:34 -0700
comments: true
categories: 
---
The current state of CM tools revolve around a centralized systems: agent/master relationships between nodes and their sources of truth. The 'master' holds the source of all data related to node configuration, e.g., their state. This design works well for most systems. However, I don't believe centralized CM tools can scale to n-number of nodes; eventually the configuration becomes to complex to manage from a single master, and you end up having to build hacks (some might not call this a hack... actually many people might not, but that's an opinion and this is my blog so..) such as duel or many masters. This creates whole new levels of complexities in the deployment. Security implementations via SSL such as certificate handling become heinous; load balances to stand the masters up behind and route network traffic need to be stood up and maintained; databases need to be reworked and tuned. Those are just a few of the extra levels of complexitites that are required when standing up very large CM deployments - no tool out there does this well, yet. 

All centralized CM systems require a 'source of truth' about what a node should be and current information about actual node state. Tools such as Puppet and Chef get the latter via Facter and Ohai - each query agent node configuration information and send it to the master as node-specific data, this is coupled with manifests or recipies or cookbooks (all I want for Christmas is a new name for a 'model') and a 'source of truth' that is either pulled directly from the models that are written or key-values placed in external yaml, json, or DB's (I've seen a Couch DB over http implementation) queried with Hiera. The master compiles the model based on a node declaration, the node facts, external and local look up of variables, and passes the compiled model back down to the agent for the agent to apply. Puppet spearheaded this distribution and its competitors quickly caught on (see Ansible Tower) - SSH in a for loop doesn't scale very well. 

However, as one can see, the scaling of this CM system can become highly complex and require an entire team of experts to deploy and maintain in very large instances. New services need to be stood up, metrics need to be gathered, the system that was brought in to scale your infrastructure becomes the noisy chic in the nest. Shouldn't this system just scale itself based on your environments needs? 

### Stateless Configuration Management 

There has been some internet chatter about stateless CM: https://www.domenkozar.com/2014/03/11/why-puppet-chef-ansible-arent-good-enough-and-we-can-do-better/

-What is it
-Where it would fail

### HA Configuration Management  

-What is it
	-maybe 'stem nodes'? with DNA
	-maybe cellular-type and nodes that "divide" based on heartbeat of system
	-enviro heartbeat
	-network as source of truth - node information exists on a message bus - this is centralized via brokers, so maybe needs more thought into implementation
	-autoscaling based on heartbeat

  

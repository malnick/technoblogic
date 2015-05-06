---
layout: post
title: "Automating Spring Boot Micro Service Deployments"
date: 2015-05-01 10:05:30 -0700
comments: true
categories: 
---
Spring is a java framework that has been around for the better part of a decade. Though some argue it's growing long in the tooth, it's still a standard among large enterprise to smaller startup style web applications. Spring boot is Springs answer to next generation, easy-to-implement, spring setup. Spring boot has a host of advantages over it's legacy counterpart, chef among them packaging up your application in jar file format vs. war file format, embedded tomcat, and the primary topic of this post: resource configuration based on config files found in the classpath.  

This seeminly simple way to configure an application provides a much needed interface for operations to successfully automate a spring application across heterogenious environments. y Since spring is Java-based we have the typical players we can roll in our init script to tune things JVM-related: XMX/XMS are key. We can also pass in active profiles, or groupings of configuration that override any application property files which in turn set "defaults" for a given deployment. 

### Key Factors
Key factors for successfull JVM-based application deployments consist of these elements:

1. Environment: production, QA, development etc
1. JVM tuning
1. $PORT assignments
1. Datastore host, username and passwords

Inevitably, all this configuration ends up in the init script. At SRC:CLR we run at minimum two JVMs on a single box for each of our micro services. This means the automation of generating that init script needs to take in not a unique service name, but a unique process reference. 

It also means the init script has to handle any number of processes of a given service. We also may want to run a different service with a completely different set of overrides than the other process, connecting to a separate datasource (queue, database..) or a unique vhost on a queue. It doesn't matter what the config is, the entire process should be completely transparent and easy to deploy.

### It's about homogenous deployments... sort of
At some point we need to have some things that are the same across all deployments, let's look at the constants:

1. Location of compiled jar, war, whatever
1. Service names
1. Deployment paths:
  1. Logrotate policies
  1. Haproxy or other layer 7 routing rule generation
  1. Root dir for the application
  1. Logging directories
1. Monitoring implementation






---
layout: post
title: "DC/OS Logging API (Day 2 Operations Part 1)"
date: 2016-09-19 13:08:44 -0700
comments: true
categories: 
author: Jeff Malnick, Nicholas Parker
---
This blog post is the first in a 3 part series on day 2 operations for DC/OS. The first part is an introduction to what we mean by "day 2 operations" and the first piece of this product road map, our logging API. Part 2 is on metrics gathering, shipping and integrations with popular metrics analytics solutions. The final part is on debugging and how we intend to build our debugging API for executing interactive sessions from the DC/OS CLI with a running task in the cluster. 
<!-- more -->
# What is day 2 operations?
It takes more to run an application in production than installing some software and starting applications. For the operator, their job truly begins on day 2 - maintaining, upgrading, debugging a running cluster without downtime. Without this "second day" of work, the question becomes, what was all this for anyway? 

Since DC/OS is an operating system, we have the perfect platform to build the APIs and functionality required for operators to be successful and efficient at their jobs. Some of the first pieces of this functionality that we are focused on here is logging, metrics and debugging.


Enabling our operators with rich API's that are generic enough to fit into any stack, whether it's ELK for logs, or Data Dog for metrics, our aim is to ship features which integrate gracefully with the operator’s favorite tools. Our focus doesn’t stop at the system components. We aim to ship metrics and logs for the applications you run on the cluster as well. This gives our operators the best possible stack for maintaining uptime and availability. No longer do operators need to implement custom solutions for every component and application running in their datacenter. They can automatically get the data needed to keep that cluster up and running. 

For those running DC/OS Enterprise Edition, they can expect these API's to be secured with the same authentication and authorization they've come to expect since the release of Enterprise DC/OS 1.8. 

We identified 3 core areas that we are aiming to ship in DC/OS 1.10:
- Logging
- Metrics
- Debugging

## DC/OS Logging API
Our aim in building a cluster-wide logging API is to ensure our operators can integrate DC/OS with any log aggregator. That means it needs to work as seamlessly with an ELK stack which is front-ended with Redis as well as it does dumping to Splunk or other hosted log systems. For our enterprise customers it needs to obey our security requirements for authorization and authentication when being queried by services or cluster operators.  

### Architecture
The logging API has one goal: make DC/OS core service logs and applications deployed to DC/OS (frameworks or containers) available through one, intuitive HTTP API. 

#### Step 1: Everything goes to Journald 
In order to do this we needed to re-design how we currently get logs from tasks. Today, DC/OS frameworks dump their `STDOUT` and `STDERR` to the [Mesos Sandbox](http://mesos.apache.org/documentation/latest/sandbox/). This isn't easily accessible or integrated with where all the other host-level (read: DC/OS core services such as Adminrouter) dump their logs. Core services or anything running as a systemd unit, dumps their  logs to [journald](https://www.freedesktop.org/software/systemd/man/systemd-journald.service.html).

Our first step then, is to make the task logs go to journald. To do this, we had to write a Mesos Module. This module takes every `STDERR` and `STDOUT` line a framework produces and mutates it for journald ingress. With this new module in place, we get all the logs on a cluster aggregated into one place, and we can build an API on top of that to expose it to the rest of the world. 


The second step is adding some structured data to the logs lines. You need more than just what a task is outputting to debug an issue. It is important to know what host the task is running on and which framework started it. Instead of requiring your developers to add that, we do it for you.

#### Step 3: Proxy the Logs API on Adminrouter
The entry point to our logging API for the DC/OS CLI, user interface or external entities will go through Adminrouter. You get access to your logs for debugging without moving them around at all. If your log aggregation infrastructure is down or you just don’t want the expense of moving bits around, we’ve got you covered.

This customized NGINX proxy figures out how to route requests to a specific host given a Mesos role ID. 
### Log Integrations

The logging API and Mesos logging module together provide the foundation for seamless integrations with popular log shipping stacks such as [ELK](https://www.elastic.co/webinars/introduction-elk-stack), [Splunk](https://www.splunk.com/) or [Fluentd](http://www.fluentd.org/). Since all the logs end up in journald, you can easily add shipping agents for these popular log aggregation stacks. These two primitive logging solutions give our customers and end-users a first class experience for both application and DC/OS service logs. 

### DC/OS CLI Node Log Command
The DC/OS CLI has had it's own log command to get framework logs to the end-user for some time. This command will not change in usage but will be leveraging this new log API. Before, users could only use this CLI command to get logs from tasks, but now they'll be able to get logs for DC/OS core services such as Adminrouter or the Mesos Master and Slave services. This is invaluable for debugging. For example, when you need to view the Marathon logs and your application logs at the same time. This is now possible from the same utility without having to SSH into a cluster host. 



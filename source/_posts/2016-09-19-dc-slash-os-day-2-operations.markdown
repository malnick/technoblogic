---
layout: post
title: "DC/OS Day 2 Operations"
date: 2016-09-19 13:08:44 -0700
comments: true
categories: 
---
Day 2 operations are actions which DC/OS operators take after the initial deployment of a DC/OS cluster. For the DC/OS operator, this is where their job truly begins; as a product, DC/OS strives to make day 2 operations as seamless and intuitive as possible. Since DC/OS is an operating system, not simply a container orchestrator (though we have frameworks such as Marathon which do that in spades), we have the perfect platform for gathering metrics, logs and implementing these intuitive debugging features that our competitors lack. 

Enabling our operators with rich API's that are generic enough to fit into any stack, whether it's ELK for logs, or Data Dog for metrics, our aim is to ship features which integrate gracefully with the most common, feature-full solutions available. And we are not aiming to ship just cluster metrics and logs, we aim to ship metrics and logs for the applications you run on the cluster as well. 

For our Enterprise customers, you can expect these API's to be secured with the same authentication and authorization you've come to expect since the release of Enterprise DC/OS 1.8. 

We identified 3 core areas that we are aiming to ship in DC/OS 1.10 for both open source and enterprise distributions:
- Logging
- Metrics
- Debugging

The only difference between the two across these distros is the enterprise version will have authorization and authentication. 

## DC/OS Logging API
Without automated log aggregation your monitoring, alerting and derived metrics are nothing. Logs provide some of the best possible insights into your application health as well as DC/OS cluster health. They're invaluable for debugging and are where first responders go when things head South.

Our aim in building a cluster-wide logging API is to ensure our operators can integrate DC/OS with any log aggregator. That means it needs to work as seamlessly with an ELK stack which is front-ended with Redis as well as it does dumping to Splunk or other hosted log systems. For our enterprise customers it needs to obey our security requirements for authorization and authentication when being queried by services or cluster operators.  

### Architecture
The logging API has one goal: make DC/OS core service logs and applications deployed to DC/OS (frameworks or containers) logs available through one, secured, intuitive HTTP API. 

#### Step 1: Everything goes to Journald 
In order to do this we needed to re-design how we currently get logs from frameworks. Today, DC/OS frameworks dump their `STDOUT` and `STDERR` to the [Mesos Sandbox](http://mesos.apache.org/documentation/latest/sandbox/). This isn't easily accessible or integrated with where all the other host-level (read: DC/OS core services such as Adminrouter) dump their logs. Core services or anything running as a systemd unit, dumps its logs to [journald](https://www.freedesktop.org/software/systemd/man/systemd-journald.service.html).

Our first step then, is to make the framework logs go to journald. To do this, we had to write a Mesos Module. This module takes every line a framework produces and mutates it using the journald API, using journald labels to mark what framework the log line is associated with along with other metadata. With this new module in place, we get all the logs on a cluster aggregated into one place, and we can build an API on top of that to expose it to the rest of the world. 

#### Step 2: Build a (secure) HTTP API on Journald
Having all the framework and container logs in journald posses some serious security risks:
1. How do we ensure authorized users access only the log data which their applications produce? 
1. How do we filter log results based on these ACLs?

For our enterprise customers, the logging API needs to follow fine-grained access control lists (ACLs) for any log line. That means, if Alice does not have permission to touch Bob's application, then she must not be allowed to access logs which pertain to Bob's application. If Bob gives Alice permission to view his application, then Alice should be able to view the Bob's application log data.  

In order to put these assurances to rest, we use the meta-data that the Mesos Logging Module amends each log line and leverage it at the application layer to ensure logs which are not meant for a specific user are not served. The logging API talks to the same services which provide fine-grained ACLs as our other DC/OS components to ensure these assurances are met.  

#### Step 3: Proxy the Logs API on Adminrouter

### Journald Performance Testing



## DC/OS Metrics Shippers // Collectors
### Shipping Metrics
### Collecting Metrics
### Integration Examples

## DC/OS Debugging API

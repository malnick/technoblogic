---
layout: post
title: "DC/OS Day 2 Operations"
date: 2016-09-19 13:08:44 -0700
comments: true
categories: 
---
This blog post is the first in a 3 part series on day 2 operations for DC/OS. The first part is an introduction to what we mean by "day 2 operations" and the first piece of this product road map, our logging API. Part 2 is on metrics gathering, shipping and integrations with popular metrics analytics solutions. The final part is on debugging and how we intend to build our debugging API for executing interactive sessions from the DC/OS CLI with a running task in the cluster. 

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
The logging API has one goal: make DC/OS core service logs and applications deployed to DC/OS (frameworks or containers) available through one, secured, intuitive HTTP API. 

#### Step 1: Everything goes to Journald 
In order to do this we needed to re-design how we currently get logs from frameworks. Today, DC/OS frameworks dump their `STDOUT` and `STDERR` to the [Mesos Sandbox](http://mesos.apache.org/documentation/latest/sandbox/). This isn't easily accessible or integrated with where all the other host-level (read: DC/OS core services such as Adminrouter) dump their logs. Core services or anything running as a systemd unit, dumps its logs to [journald](https://www.freedesktop.org/software/systemd/man/systemd-journald.service.html).

Our first step then, is to make the framework logs go to journald. To do this, we had to write a Mesos Module. This module takes every `STDERR` and `STDOUT` line a framework produces and mutates it for journald ingress, using journald labels to mark what framework the log line is associated with along with other metadata. With this new module in place, we get all the logs on a cluster aggregated into one place, and we can build an API on top of that to expose it to the rest of the world. 

#### Step 2: Build a (secure) HTTP API on Journald
Having all the framework and container logs in journald could be a security risk, so our first design goal was how we'd secure the API:
1. How do we ensure authorized users access only the log data which their applications produce? 
1. How do we filter log results based on these ACLs?

For our enterprise customers, the logging API needs to follow fine-grained access control lists (ACLs) for any log line. That means, if Alice does not have permission to touch Bob's application, then she must not be allowed to access logs which pertain to Bob's application. If Bob gives Alice permission to view his application, then Alice should be able to view the Bob's application log data.  

By using the meta-data that the Mesos Logging Module amends each log line and leverage it at the application layer to ensure logs which are not meant for a specific user are not served. The logging API talks to the same services which provide fine-grained ACLs as our other DC/OS components to ensure these assurances are met. In this way, our logging API is secured with fine-grained ACL's at the application layer. Our final step is proxying every instance of this API, which runs on every role and thus every host in the DC/OS cluster.  

#### Step 3: Proxy the Logs API on Adminrouter
The entry point to our logging API for the DC/OS CLI, user interface or external entity will go through Adminrouter. This customized NGINX proxy figures out how to route requests to a specific host given a Mesos role ID. By going through Adminrouter, we also win with coarse-grained ACL's which ensure initial perimeter defense against outside requests to our log API. The Adminrouter implementation is fairly straightforward as it's just another upstream in the NGINX config. On Enterprise and Open variants we have basic coarse-grained authorization via a Lua script that ensures the requestee is logged in and authorized to access the DC/OS cluster. 

### Log Integrations
The logging API and Mesos logging module together provide the foundation for seamless integrations with popular log shipping stacks such as [ELK](https://www.elastic.co/webinars/introduction-elk-stack), [Splunk](https://www.splunk.com/) or [Fluentd](http://www.fluentd.org/). Since all the logs end up in journald, you can easily add shipping agents for these popular log aggregation stacks. Through ACL's within those systems, you can then build your own secured log viewing solution or charts. Or, if you want to build into our logging API, you can design a secured log aggregation solution for almost any need by leveraging the HTTP stack. In any case, these two primitive logging solutions give our customers and end-users a first class experience for both application and DC/OS service logs. 

### DC/OS CLI Node Log Command
The DC/OS CLI has had it's own log command to get framework logs to the end-user for some time. This command will not change in usage but will be leveraging this new log API. Before, users could only use this CLI command to get logs from frameworks, but now they'll be able to get logs for DC/OS core services such as Adminrouter or the Mesos Master and Slave services. This is invaluable for debugging. For example, when you need to view the Marathon logs and your application logs at the same time. This is now possible from the same utility without having to SSH into a cluster host. 

## DC/OS Metrics Shippers // Collectors
DC/OS has two main focus points for metrics: framework and container metrics - the metrics from applications you deploy to a DC/OS cluster; cluster host metrics - metrics about host memory, CPU, storage, load and cGroup allocations. Both cases have almost endless possibilities for metric gathering. We mentioned a few specific metrics regarding host level metrics, but how do we know what metrics to gather from a deployed container on DC/OS? We don't, so to enable our end-users we've simply made a [statsd](https://github.com/etsy/statsd) port available to any deployed container. This port number is available via an environment variable inside the container: `STATSD_PORT`.   

### Shipping Metrics
As mentioned, shipping metrics from a deployed container is made simple through the use of statsd and an environment variable to expose the port your shipper needs to dump to. For host level metrics we have a host level shipper that we're building which will also dump statsd metrics about memory, CPU, load, storage and other important host level metrics, to a unified metrics collector. This collector will exist on each host, and serve as the single point of metrics aggregation from both containers and the host. 

### Collecting Metrics
To collect metrics from containers and host-level resources we build a unified collector. This collector can be configured to dump metrics to either Kafaka or another statsd aggregation solution. These outputs are referred to as producers. In the case of the Kafka producer, you'll most likely need a Kafka cluster available in the DC/OS cluster or otherwise available over the network to ship to. The statsd producer is intended as a more generic metrics shipping solution, since many stacks exist that can ingest statsd metrics. 

As with all our day 2 operations API's, our end-goal is ease of integration with popular stacks and solutions. In the future we'll add more producers to the unified collector on each host so you can ship to even more metrics analytics endpoints. 

### Integration Examples

## DC/OS Debugging API

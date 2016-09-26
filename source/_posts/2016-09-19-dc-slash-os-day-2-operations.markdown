---
layout: post
title: "DC/OS Day 2 Operations"
date: 2016-09-19 13:08:44 -0700
comments: true
categories: 
author: Jeff Malnick, Nicholas Parker
---
This blog post is the first in a 3 part series on day 2 operations for DC/OS. The first part is an introduction to what we mean by "day 2 operations" and the first piece of this product road map, our logging API. Part 2 is on metrics gathering, shipping and integrations with popular metrics analytics solutions. The final part is on debugging and how we intend to build our debugging API for executing interactive sessions from the DC/OS CLI with a running task in the cluster. 


# What is day 2 operations?

It takes more to run an application in production than installing some software and starting applications. For the operator, their job truly begins on day 2 - maintaining, upgrading, debugging a running cluster without downtime. Since DC/OS is an operating system, we have the perfect platform to build the APIs and functionality required for operators to be successful and efficient at their jobs. Some of the first pieces of this functionality that we are focused on here is logging, metrics and debugging.


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

## DC/OS Metrics

DC/OS has three main focus points for metrics:

- Host metrics: metrics about the host systems themselves
- Container metrics: metrics about the resource utilization of each container
- Task metrics: metrics emitted by the deployed applications within each container

Across these areas there are endless possibilities for metric gathering. We'll discuss how we approach each of these cases. For more information, see our recent [presentation at Mesoscon EU](http://schd.ws/hosted_files/mesosconeu2016/e7/Metrics%20on%20DC-OS%20Enterprise%20%28Mesoscon%29.pdf).

### Host Metrics
Host metrics such as system-wide CPU usage, Memory usage, and System load are automatically collected for each system in the cluster. This information is automatically tagged with the system it came from, via the `agent_id` tag. Because we’re running an agent on every host in the cluster, we can parse the cgroups hierarchy and publish these for free.

### Container Metrics
In addition to the metrics collected for the system as a whole, metrics are also automatically collected for each container on that system, and those data are automatically tagged to identify the container. These metrics mainly focus on resource utilization, as containers are a effectively collection of allocated resources after all.

### Task Metrics

While it's easy to think about collecting system-level metrics, we'd also like to allow tasks themselves to emit their own custom metrics. This opens a world of possibilities, as it effectively allows every task in the cluster to emit any measurable value at any time. These values can then be decorated automatically with metadata to assist in debugging, such as the host it was running on and the framework that started it.

For this case, we explicitly sought a solution that was easy to integrate with any application, written in any programming language. To this end we expose two environment variables to each container: `STATSD_UDP_HOST` and `STATSD_UDP_PORT`. Any statsd-formatted metrics sent by the application to this environment-advertised endpoint will automatically be tagged with the originating container and forwarded to the rest of the metrics infrastructure. The [Datadog StatsD tag format](http://docs.datadoghq.com/guides/dogstatsd/#datagram-format) is also supported by this endpoint, so any such tags produced by the application will automatically be parsed out and included in the forwarded data. But from the application's perspective, it only needs to check for those two environment variables and configure a local emitter to send the metrics. The rest is handled automatically.

To see some examples of this integration in practice, see how it's done by the [DC/OS Apache Cassandra](https://github.com/mesosphere/dcos-cassandra-service/blob/964fc1e5d6809a8b2dc040efe9c065405ff56118/cassandra-executor/src/main/java/com/mesosphere/dcos/cassandra/executor/metrics/MetricsConfig.java#L68) and [DC/OS Apache Kafka](https://github.com/mesosphere/dcos-kafka-service/blob/acf844c413ddb8ea7bdb2b1f58b1d79e56c8c6ad/kafka-config-overrider/src/main/java/com/mesosphere/dcos/kafka/config/Overrider.java#L163) services. In each of these cases, it was straightforward to configure even third-party code to support DC/OS Metrics, without needing to touch the code itself for either of these services (modulo the addition of necessary .jars to support emitting StatsD).

### Tagging Metrics

In order to support easy drill-down, filtering, and grouping of metrics data, all data sent through the DC/OS Metrics stack is automatically tagged with its origin. The tags include the following, but this list is expected to grow over time:

- Container identification (for all Container and Application metrics): `container_id`, `executor_id`, `framework_id`, `framework_name`
- Application identification (for e.g. Marathon apps): `application_name`
- System identification: `agent_id`

For example, grouping metrics by `agent_id` would allow an administrator to detect a situation that's system-specific (eg a faulty disk). Meanwhile grouping data by `framework_id` would allow them to detect which Mesos Frameworks are using the most resources in the system, and grouping that data by `container_id` would show the same information except with per-container granularity.

### Forwarding Metrics

Now that metrics have been collected from the applications and from the host itself, they need to be forwarded to a customer-managed location so that the customer can consume them. As with all our day 2 operations API's, our end-goal is ease of integration with popular stacks and solutions. To forward that goal we currently support two widely used methods for outputting the metrics data from the cluster. These methods are:

- Kafka service (either in DC/OS itself, or external to the cluster). Widely understood performance and maintenance characteristics. Good throughput for larger clusters.
- StatsD service (eg `dogstatsd` or the original Etsy `statsd`). Lighter-weight solution for smaller clusters, where running a Kafka instance may be overkill. Optionally supports outputting [s[satadog-format tags.

In either of these cases, it's extremely easy to consume the outputted metrics data and forward it to any customer-managed or third-party monitoring infrastructure.

## DC/OS Debugging API

Things fail in production, many times it takes more than the logs to understand what’s going wrong. Instead of requiring end users to SSH arbitrarily across the cluster and have root access, we have built a single tool that can access any running container from a developer’s laptop without having to figure out where it is running.

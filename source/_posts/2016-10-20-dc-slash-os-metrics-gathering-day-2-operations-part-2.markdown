---
layout: post
title: "DC/OS Metrics Gathering (Day 2 Operations, Part 2)"
date: 2016-10-20 13:28:52 -0700
comments: true
categories: 
---
## DC/OS Metrics
DC/OS has three main focus points for metrics:

- Host metrics: metrics about the host systems themselves
- Container metrics: metrics about the resource utilization of each container
- Task metrics: metrics emitted by the deployed applications within each container

Across these areas there are endless possibilities for metric gathering. We'll discuss how we approach each of these cases. For more information, see our recent [presentation at Mesoscon EU](http://schd.ws/hosted_files/mesosconeu2016/e7/Metrics%20on%20DC-OS%20Enterprise%20%28Mesoscon%29.pdf).
<!-- more -->
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



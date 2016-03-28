---
layout: post
title: "System Health at Enterprise Scale"
date: 2016-03-25 10:04:54 -0700
comments: true
categories: 
---
The Data Center Operating System (DCOS) runs on tens of thousands of hosts. Monitoring the health of all the pieces that make up this amazing application is vital to data center operators and for troubleshoooting hard-to-diagnose bugs. In DCOS v1.7 we're releasing a new system health API to monitor the core DCOS components (more on the terminology of 'components' later). In the futrue we're hoping to expand the usage of the system health API to other metrics as well as exposing a plugins-style architecture to allow operators to customize system health monitoring.
<!-- More -->

## Getting Started
If you're using DCOS 1.7, getting started with System Health is easy. When you launch your new cluster, you'll notice a new application badge in the main DCOS user interface:

![login](https://dl.dropboxusercontent.com/u/77193293/systemHealthScreens/dcos_ui.png)

You can click on this badge, taking you to the main system health user interface:

![badge](https://dl.dropboxusercontent.com/u/77193293/systemHealthScreens/badge_close.png)

You can sort by health:

![sort](https://dl.dropboxusercontent.com/u/77193293/systemHealthScreens/sort_by_health.png)

When a component isn't healthy, you can drill in on it, seeing all the nodes on which that component runs:

![view](https://dl.dropboxusercontent.com/u/77193293/systemHealthScreens/sys_unhealthy_view.png)

You can debug more by clicking the node, where you'll be able to see the unhealthy component journald (log) output:

![log](https://dl.dropboxusercontent.com/u/77193293/systemHealthScreens/sys_unhealthy.png)

## Components
What we refer to as components are in fact the [systemd units](https://www.freedesktop.org/wiki/Software/systemd/) that make up the core of the DCOS application. These systemd 'components' are monitored by our internal diagnostics utility (dcos-diagnostics.service). This utility scans all the DCOS units, and then exposes an HTTP API on each host. 

You can query this HTTP API for any host in the cluster:

```
curl <host_ip>:1050/api/v1/health
```

## Aggregation
Aggregation of the cluster health endpoints is actually accomplished by the same diagnostics application, except this aggregation mode is only ran on master hosts. You can explore this API further by making a few queries to any master in your cluster:

```
curl <master_ip>:1050/api/v1/health/units
curl <master_ip>:1050/api/v1/health/nodes
curl <master_ip>:1050/api/v1/health/report
```

The DCOS user interface uses these aggregation endpoints to generate the data you explore in the system health console.

## Health States
Today, there are only binary health states, ```healthy``` and ```unhealthy```. We infer this from codes 0 and 1 respectively. We did however build the system health API to have four possible states: 0 - 3, OK; CRITICAL; WARNING; UNKNOWN.

In the future we will leverage these codes to give more robust and detailed cluster health state information.

## That's It!
That's it for the system health addition to the DCOS ecosystem. We're going to be adding many more features in upcoming releases to DCOS, stay tuned to this blog for more information.

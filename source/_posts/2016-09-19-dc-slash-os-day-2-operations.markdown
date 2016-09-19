---
layout: post
title: "DC/OS Day 2 Operations"
date: 2016-09-19 13:08:44 -0700
comments: true
categories: 
---
Day 2 operations are actions which DC/OS operators take after the initial deployment of a DC/OS cluster. At Mesosphere, we place high value on this critical time period. For a DC/OS operator, this is where their job truely begins. We at Mesosphere also believe that this is where DC/OS truely shines. Since DC/OS is an operating system, not simply a container orchestrator (though we have frameworks such as Marathon which do that in spades), we have the perfect platform for gathering metrics, logs and implementing intuitive debugging features that our competitors lack. 

Enabling our operators with rich API's that are generic enough to fit into any stack, whether it's ELK for logs, or Data Dog for metrics, our aim is to ship features which interate gracefully with the most common, feature-full solutions available. And we are not aiming to ship just cluster metrics and logs, we aim to ship metrics and logs for the applications you run on the cluster as well. 

For our Enterprise customers, you can expect these API's to be secured with the same authentication and authorization you've come to expect since the release of Enterprise DC/OS 1.8. 

We identified 3 core areas that we are aiming to ship in DC/OS 1.10 for both open source and enterprise distributions:
- Logging
- Metrics
- Debugging

The only difference between the two across these distros is the enterprise version will have authorization and authentication. 

## DC/OS Logging API
The loggin

## DC/OS Metrics Shippers // Collectors
### Shipping Metrics
### Collecting Metrics
### Integration Examples

## DC/OS Debugging API

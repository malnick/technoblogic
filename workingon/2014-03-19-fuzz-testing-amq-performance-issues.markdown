---
layout: post
title: "Fuzz Testing AMQ Performance Issues "
date: 2014-03-19 10:44:43 -0700
comments: true
categories: 
---
Recently I've been digging into the backend of Apache ActiveMQ for Puppet Enterprise. In one customer-facing troubleshooting session I was trying to diagnose some performance issues. To make things clearer it would have been useful to see what AMQ was doing on the application level. 

In AMQ for PE we use Simple (or Streaming) Text Oriented Message Protocol AKA STOMP for application level communication between our AMQ client (mCollective) and the AMQ broker and again to the AMQ agents. STOMP is application level, i.e., it's like HTTP for message orietned middlewear (MOM). 

Like another popular MOM application communication protocol, the Advanced Message Queuing Protocol (AMQP), STOMP works over TCP/IP. I want to see what it takes to track only AMQ messages over the network. My drug of choice for packet sniffing is wireshark (tshark mostly) and tcpflow to track packet data and not just wire transaction crap.

### TCP Tracking

AMQ STOMP sessions run over TCP, so I need to build a TCP follow session for the AMQ STOMP stream. Since I don't know what stream to follow just yet, I'll look for AMQ ports that are used (61613) and do an MCO ping:

{% codeblock %}
[root@malnick yum.repos.d]# tshark port 61613
Running as user "root" and group "root". This could be dangerous.
Capturing on eth0
  0.000000  10.0.20.116 -> 10.0.20.108  TCP 74 60352 > 61613 [SYN] Seq=0 Win=14600 Len=0 MSS=1460 SACK_PERM=1 TSval=50533310 TSecr=0 WS=64
  0.194059  10.0.20.108 -> 10.0.20.116  TCP 74 61613 > 60352 [SYN, ACK] Seq=0 Ack=1 Win=14480 Len=0 MSS=1460 SACK_PERM=1 TSval=36890443 TSecr=50533310 WS=64
{% endcodeblock %}

and from a separate console I run:

{% codeblock %}
peadmin@malnick:/root$ mco ping
gonzo.puppetlabs.vm                      time=124.96 ms
malnick.puppetlabs.vm                    time=136.70 ms
raja.puppetlabs.vm                       time=1189.92 ms
ian.puppetlabs.vm                        time=1192.96 ms
^C

---- ping statistics ----
4 replies max: 1192.96 min: 124.96 avg: 661.14
peadmin@malnick:/root$
{% endcodeblock %} 




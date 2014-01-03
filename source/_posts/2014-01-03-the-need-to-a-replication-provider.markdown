---
layout: post
title: "The Need for a Replication Provider"
date: 2014-01-03 09:05:51 -0800
comments: true
categories: [puppet,ruby,providers]
---
###Why we need a replication provider for puppet
I've been using puppet for over a year now. I started using it at the request of a friend who wanted a simple, one-liner command to boot his e-commerce platform on Vagrant VM's for dev and eventually production. I was impressed by the simplicity, the software defined server-state was easy to create through the elegant package, resource, service workflow. It wasn't very long that we found other more advanced needs for Puppet. 

One of these needs was booting multiple MySQL server slaves on a single host machine to replicate various MySQL masters. The masters were any one of the customers currently using this e-commerce platform. The distributed nature of the servers and the cost-benefit of running a single slave server (a beefy host nonetheless) for all of them presented a few challenges. 

First off, nobody wants to be a sysadmin. This company was small in terms of manpower and everyone was already in a DevOps role, but who wants to sit around running "CHANGE MASTER TO"... all day? Not your python dev that's for sure. So we decided it was best to build out a Puppet module that can run on the slave and master hosts that would:

1. Boot multiple MySQL slaves on one host
2. Dump the master MySQL DB and scp to the slave (once the slave was provisioned)
3. Import the scp'ed DB to the slave and start replication from the correct binlog position

Simple right? Yeah... right. 

Let's cut the chase: how many lines of puppet code did it take for me to write a unique mysql slave instance onto a host? 

167

For each slave I needed to provision:
	*/var/lib/mysql_instance#
	*/var/log/mysql_instance#
	*/etc/mysql_instance#
	*/etc/mysql_instance#/my.cnf
	*Customize that my.cnf for the instance

Which looks like standard Puppet fun:
	
{% include_code slave.rb range:62-97 %}

Then I needed to boot a DB with the datadir, and from that point on it was, well, you know, a bash script basically with a million exec statements:

{% include_code slave.rb %}



 
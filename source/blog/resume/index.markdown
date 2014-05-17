---
layout: page
title: "Resume"
date: 2014-03-20 10:26
comments: true
sharing: true
footer: true
---
##Profile

Systems administrator with 7 years of *nix computing experience. Experience in several $scripting_languages (Ruby [Puppet, Chef, mCollective API, Vagrantfiles, Rakefiles], Bash [automation, systems configuration/management, Makefiles]). Good at troubleshooting other code bases (Java, JavaScript, NodeJS, C, C++) to find out where dev broke ops. Highly proficient in systems configuration using Puppet, also has under the hood experience with chef, ansible and salt. Understanding of continuous integration pipelines; experience deploying continuous delivery pipelines of spec tested code from dev through production. Excellent understanding of use and implementation of git and git workflows. Good understanding of the JVM platform - in particular, experience tuning the JVM for ActiveMQ messaging brokers/agents. Plays well with others. 

##Experience

###Puppet Labs, Professional Services Engineer

December 2013 - Present

Pro services @puppetlabs: Customer-facing problem solving role. Teach the Puppet DSL at various public and private venues. Contribute to the development of Puppet in the areas of rapid deployment/continuous integration; trouble-shooting and QA testing of new puppet-oriented technologies such as R10k; develope respec tests for unit and integration testing of Puppet code. Help deploy Puppet Enterprise to customer sites and consult on customer needs developing Puppet modules and code as needed.

###Cart Logic, Inc. Development & Operations

March 2013 - August 2013

Private consulting services at contracting rates for Cart Logic, Inc. 

Deployed the Cart Logic e-commerce platform via monolithic puppet manifest and associated module directory. Platform driven by a Python Pyramid framework consisting of over 5000 nose tests. The deployment consisted the monolithic manifest on a clean Ubuntu 12.04 LTS box, passing all nose tests 100% and serving the base html templates in a web browser post puppet run. Deployment testing and configuration were all done in Vagrant. Final deliverable was the monolithic manifest and associated repo of modules plus Vagrantfiles. 

Automated the MySQL replication bootstrapping process for new client databases. Wrote a MySQL Replication module that runs a replicate::master defined type (not idempotently) to configure a MySQL master node instance. Slave nodes could have the same module ran on them using the replicate::slave defined type. The objective was to have multiple remote masters with all slave instances running on a single monolithic MySQL slave server - my module would have to boot a new unique MySQL database/server for each slave instance. I’m currently attempting to turn the replication services in this module into a puppet provider for the puppetlabs/mysql module: https://github.com/malnick/replication-provider-dev-vm/tree/master/modules/replicate

###Naval Postgraduate School, Research Associate

December 2007 - December 2013

Systems administration for distributed high performance optical networks leveraging a local Sun Blade super computer for distributed media streaming and rendering services such as live 4k and 8k video. Developed RHEL and Debian skills. Developed pipelines and workflows for generating, editing and distributing high bandwidth media for live and asynchronous viewing. Contributed to projects in the Space Systems department in rigid body motion capture and helped write a plugin for the Vicon motion capture suite to stream live x,y,z coordinates of moving objects from said system. Wrote scripts for STIGing computers in according with SCAP security requirements mandated by the DoD and eventually helped develop to Puppet modules to automate this task for the 12+ versions of linux under support from the IT department, spanning 20+ systems administrators and 280 *nix nodes.

###Skills & Tool Shed 

**Network Stack Experience**

```
HTTP[s] - SNMP - NTP - FTP - DHCP - STOMP - Telnet 
	\-> TCP - UDP - SCTP
		\-> IP - ICMP 
			\-> IEEE 802.2 - ARP
				\-> Link layer 
```

**Skills**

* Config Mgmt: Puppet (Certified Puppet Professional) - Ansible - some Chef & Salt 
* Orchestration: mCollective - salt
* Git! 
* *nix: RHEL - Debian - Ubuntu - CentOS - SUSE (ugh, Zypper)
* Message Oriented Middleware: ActiveMQ in Publish/Subscribe framework over STOMP 
* Metric gathering & Monitoring: Nagios - Ganglia - Munin 
* Database: MySQL/HA MySQL - Postgres - CouchDB 
* Loadbalancing: HA Proxy 
* Interchange formats: JSON - YAML - XML 
* NTP:  to manage SSL certs in a PKI infrastructure - also used to sync timecode between cameras in streaming of 4k video in a live channel in production. 
* SAN: Managed 50TB SAN system for archival of 4k media assets served over 10g backplane to a NTT-developed server for live streaming and recording. 

**Dev**

* github.com/malnick
* Bash, Sh 
* Ruby - but not as much as Bash. 
* Python - but not as much as ruby. 
* Once upon a time I knew Perl, and before that fourth and before that C++.  

**Tools**

* Vagrant
* Wireshark 
* Vim
* VMWare (if you include Fusion as an actual tool)
* (r)spec testing suites (rspec-puppet)
* Continuous integration tools such as Jenkins
* r10k
* git
* O’Reilly books

###School

Naval Postgraduate School: partial MS, Computer Science 2012

UC Santa Cruz: BA, Feminist Studies 2007

General Class Amateur Radio Operator, (KF6ZLP) 1999 - Present Lots of really awesome mentors, 1984 - Present.

###Stuff I do for fun

USAC/UCI Professional Mountain Biker

USAC/UCI Category 1 Cyclist

Photography

I like hacking radios and learning crypto. I don’t read fiction.

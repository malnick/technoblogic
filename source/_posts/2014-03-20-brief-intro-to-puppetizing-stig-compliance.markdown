---
layout: post
title: "Brief Intro to Puppetizing STIG Compliance"
date: 2014-03-20 10:01:05 -0700
comments: true
categories: 
---
STIG is a methodology for the implementation of security compliance across heterogeneous operating systems. Every OS has a specific STIG. The STIG for a given OS is maintained and distributed by the Defense Information Systems Agency (DISA). Current STIGs can be found on the [DISA website](http://iase.disa.mil/stigs/).
 
Puppet is an excellent tool for bringing machines into STIG compliance. At my previous job I was in [shell script hell](https://github.com/malnick/do_debian_stig/blob/master/do_debian_stig.sh) until we spun up a POS master and started writing a STIG module that worked across all OS's we supported (14 linux distros, 30 territorial sys admins, ~250 nodes).

In doing a STIG module for puppet it’s best to just work from Cat 1 down. 1 & 2 offenses are pretty big, 3 & 4 are usually minor security patches and can be overlooked if you’re time crunched. Staying on top of the false positives and keeping your module up to date with actual security implementation is the biggest hurdle. 
 
This document is a general guideline from my experience in implementing STIG compliance measures.

### Basic STIG Process

1. Go to the DISA site and download the STIG for the appropriate OS
 
2. Do some sort of benchmark scan on a base OS:
     - I used retina (which is awful) scans that were preloaded with the appropriate [Security Content Automation Protocol (SCAP)](http://www.public.navy.mil/spawar/Atlantic/ProductsServices/Pages/SCAP.aspx) documents (.xml files, see below).
      - You can also get SCAP benchmarks on the DISA site for the appropriate OS listed with the STIG benchmarks (see below on SCAP)

3. Take retina report with categorized vulnerabilities and start writing puppet modules - oh wait, just kidding! first you’ll need to:
 
     a. Check for false positives - in most cases the OS provider is way ahead of the game, and simply running ‘apt-get update’ or ‘yum update’ will take care of 80% of the vulnerabilities on the box. STIG guidelines are notoriously behind the OS and will have LOTS of false positives. Most of your time will be spent accounting for what is actually a vulnerability and what is actually already patched by the OS provider.
 
4. What vulnerabilities are left after cross correlating with security patches are what you have to develop specified puppet classes for, this is actually the easy part.
 
A really good resource for this is the [Aqueduct Project](https://fedorahosted.org/aqueduct/wiki/RhelStigProcess) at Fedora. They’re really good about staying on top of the recent STIG process and also maintaining a set puppet module for STIGing RHEL boxes (or at least they used to, not sure what their status is now. A recent look shows they're only on RHEL 5 so...).

### SCAP

The Security [Content Automation Protocol (SCAP)](http://scap.nist.gov) is a protocol developed by the NSA puppet branch of government known as NIST for implementing IT security measures. Some parts of the protocol can be useful in scanning tools such as retina since the XML format for the vulnerability index are standardized.
 
For example, when you are on the DISA site looking at the current STIG for a specific OS there will be a download button for 'SCAP Benchmarks'. This is a .zip of several .xml's that contain:
 
[Common Platform Enumeration (CPE)](http://scap.nist.gov/specifications/cpe/) files for describing and identifying classes of applications, operating systems, and hardware devices present among an enterprise's computing assets.
 
[Open Vulnerability and Assessment Language (OVAL)](http://oval.mitre.org) for assessing and reporting upon the rachine state.
 
[Extensible Configuration Checklist Description Format (XCCDF)](http://scap.nist.gov/specifications/xccdf/index.html) which is a structured collection of security configuration rules for some set of target systems.
 
... and maybe some other random ones as well.
 
This is a document in motion so I'll be adding more here, feel free to add as you find information as well.

---
layout: post
title: "The Proxy Module"
date: 2014-10-29 20:50:15 -0700
comments: true
categories: 
---
In puppet land there are a lot of different phrases and keywords that float around: "atomic modules", "Roles and Profiles", "wrapper modules". 

This post disects these terms and others, and proposes a new type of site-specific, not-quite-a-wrapper module and not-quite-an-atomic module called the "Proxy Module". 

## It's about solutions
We have a number of custom apt stores in our infrastrcture. In order to provision both our apt repos and our apt clients to our custom PPA's and Sources, we wrote a profile called apt_client_config and apt_repo.pp. These profiles lived in the profiles module, naturally. However, since they were called from profiles, we had several instances where another module being called from that profile also depended on apt. In which case, we would run into duplicate dependencies, looped graphs, and all the other expected outcomes of using a module whose bits and pieces are needed by many other modules, at such a high level of abstraction. 

The solution was to create a proxy module. This module would wrap up just the pieces of apt that needed to be instanciated at the profile level. So, instead of running apt-based profiles in run stages at the profile level, we would run our proxy module to apt that ran just the defines we needed. These defines would be fed data from hiera via create_resources(). In this way, the proxy module differs from an atommic one - it's still wrapping up another module, but since it's so site-specific, we omit the params.pp. We don't want this module to "work out of the box", we want it to fail if it doesn't get our site-specific from hiera. 

## The implementation
The init.pp for our apt proxy module, named cs_apt (since we're Connect Solutions):

```
# Class: cs_apt
#
# Parameters:
# [*always_update*]
# boolean value to determine if apt-get update should be run every time the
# class is instantiated
#
# [*ppas*]
# Hash of type apt::ppa to add to host
#
# [*purge_sources_list*]
# Boolean value to determine if sources should be purged from host. True for
# FedRAMP
#
# [*purge_sources_list_d*]
# Boolean value to determin if source.d/* should be purged from host.
#
# [*sources*]
# Hash of type apt::source to add new ppa sources to host
#
# Requires:
# n/a
#
# Sample Usage:
# See README.md
class cs_apt (
	$always_update 		= hiera('cs_apt::always_update'),
	$ppas 			= hiera('cs_apt::ppas'),
	$purge_sources_list 	= hiera('cs_apt::purge_sources_list'),
	$purge_sources_list_d 	= hiera('cs_apt::purge_sources_list_d'),
	$sources 		= hiera('cs_apt::sources'),
) {
case $::osfamily {
'debian' : {}
default: { fail("${::osfamily} is not supported with module") }
}
validate_bool($always_update)
validate_bool($purge_sources_list)
validate_bool($purge_sources_list_d)
if $ppas {
validate_hash($ppas)
}
if $sources {
validate_hash($sources)
}
# Update repo cache and purge sources is necessary
class { '::apt':
always_apt_update => $always_update,
purge_sources_list => $purge_sources_list,
purge_sources_list_d => $purge_sources_list_d,
}
if $ppas {
create_resources('::apt::ppa', $ppas)
}
if $sources {
create_resources('::cs_apt::source', $sources)
}
}
# vim: ts=2 sw=2
```


Then in our profiles, to configure an apt source, we simply 

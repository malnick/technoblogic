---
layout: post
title: "Debugging PHP Bindings in Puppetlabs/MySQL &amp; Apache Modules"
date: 2014-04-21 14:08:37 -0700
comments: true
categories: 
---
As a Professional Services Engineer part of my job is teaching the Puppet DSL in various public and private venues throughout the United States. For our course on Puppet Fundamentals we end the final day with a capstone lab where the students deploy a profile class that provisions a wordpress website using three common Puppet modules: hunner/wordpress, puppetlabs/mysql, puppetlabs/apache.

After I let the students struggle with this seemingly difficult task I run through the deployment process step-by-step. I convey the use of module documentation on the forge and github to figure out how the modules work and then proceed to show how I came to the final model of code that actually provisions the blog - all told it can be done in 9 lines of puppet code!

I ran into an issue last week with our new VM where the PHP bindings would not load properly, here is my profile:

{% codeblock %}
class profiles::myblog (
  $docroot = undef, #hiera evaluates to /var/www/html
){
$install_dir = $docroot

class {'wordpress':
  install_dir => $install_dir,
}

class {'mysql::server':}
class {'mysql::bindings': php_enable => true, }

include apache
include apache::mod::php
}
<% endcodeblock %>



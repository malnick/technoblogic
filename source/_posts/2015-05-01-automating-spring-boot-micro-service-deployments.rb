---
layout: post
title: "Automating Spring Boot Micro Service Deployments"
date: 2015-05-01 10:05:30 -0700
comments: true
categories: 
---
Spring is a java framework that has been around for the better part of a decade. Though some argue it's growing long in the tooth, it's still a standard among large enterprise to smaller startup style web applications. Spring boot is Springs answer to next generation, easy-to-implement, spring setup. Spring boot has a host of advantages over it's legacy counterpart, chef among them packaging up your application in jar file format vs. war file format, embedded tomcat, and the primary topic of this post: resource configuration based on config files found in the classpath.  

This seeminly simple way to configure an application provides a much needed interface for operations to successfully automate a spring application across heterogenious environments. y Since spring is Java-based we have the typical players we can roll in our init script to tune things JVM-related: XMX/XMS are key. We can also pass in active profiles, or groupings of configuration that override any application property files which in turn set "defaults" for a given deployment. 

Typical Sping-based deployments suffer from configuration being hard coded into the application properties files of the code repository. This is great for modularizing your code base so it can be transported to multiple environmnets. However it ensures your code also has clear text passwords, api keys and other data that shouldn't be in a VCS repo or distributed in any way.

In order to lock down the security of the code base itself we decided to externalize all the passwords, api keys and other confidential data from our code base. Spring makes it remarkably easy to do this, providing the options to specify configuration as environment variables at boot or specify external application property files to an init script or CLI call.

## Method 1: External App Properties
First, lets talk about how we provision a node that runs our backend Spring services. Everything is managed with Puppet, which allows us to take advantage of encrypted YAML as a datasource via [Hiera](https://docs.puppetlabs.com/hiera/1/). We wrote a module around the deployment of our Spring services which takes care of the absolute neccessities for the proper configuration of our service. Via this module we're able to implement:

- Securely pulling the jar file from S3 with an ephemeral IAM user using the [S3 module](https://github.com/malnick/puppet-s3) given a specific $version
- Deploying the service to /opt/sourceclear/$service/$service.jar and symlinking the versioned jar to the executed inode
- Logstash & logrotate configuration for the service
- Exported balancermember resources for Haproxy for each process of each service that is running on a $node
- Externalized application-$app.properties file specifying the passwords, api keys and other encrypted data from eYaml
- An init script for init.d which runs 'n' number of processes specified by the $proc_opts hash sc_services::services defined type. 
- Configure application metric monitoring for New Relic 
- Define JVM Heap size for each process

A typical service might have the following deployment in Puppetland:

```ruby
class profiles::sc_services::some_service ( $version ){

  $properties_file = {
    'rabbitmq.password' => hiera('qa::rabbitmq_password'),
    'mandrill.api.key'  => hiera('qa::mandrill_api_key'),
  }

  # The main service definition
  sc_services::service { $some_service:
    deploy_stage        => 'qa',
    version             => $version,
    enable_newrelic_apm => true,
    loadbalancer_role   => 'qa_internal',
    xmx_setting         => '512',
    xms_setting         => '512',
    proc_opts           => {
      '1'  => {
        'env_profile' => 'qa',
        'port'        => '55000',
        'mgmt_port'   => '55010',
        'override'    => $properties_file,
      },
      '2'  => {
        'env_profile' => 'qa',
        'port'        => '55001',
        'mgmt_port'   => '55011',
        'override'    => $properties_file,
      }
    }
  }
}
```

This configuration will boot a node with an init script managing 2 Java processes for $service. Each prcess gets it's own exported balancermember resource for our internal haproxy in the environment 'qa' as well as New Relic APM monitoring, and most importantly an externalized configuration built from data in git that is encrypted. 

## Method 2: Environment Variables
Since Sping allows you to also override any configuration as ENV variables it makes it incredibly easy to roll this service into a docker container:

```ruby
  $rabbitmq_password  = hiera('rabbitmq_password')
  $mandrill_api_key   = hiera('mandrill_api_key')

  $env_variables = [
    "rabbitmq.password=${rabbitmq_password}",
    "mandrill.api.key=${mandrill_api_key}",
  ]

  docker::run { 'some_service':
    image           => "our_priv_registry:5000/some_service-${version}",
    ports           => ['55010'],
    expose          => ['55010'],
    env             => $env_variables,
    restart_service => true,
    privileged      => false,
    pull_on_start   => true,
  }
```

Now we can toss out an on-system properties file and keep the secure passwords purely in the context of the shell which they are executed. This furthers security as the passwords are never actually written to the system, they can not be copied or read from disk as it were. 

Of course, this simple docker example doesn't run multiples of the service but we could easily write a small module around docker which does. However, our Docker deployment is more about moving towards mesosphere as our service execution framework. This way, configuration management will not be used at all for booting and running our Docker containers. Instead, we'll be POSTing the container, the number of instances, and ENV variables to a a Mesos master which will manage the service discovery, runtime persistance and aggregation of the services in our AWS deployment. 

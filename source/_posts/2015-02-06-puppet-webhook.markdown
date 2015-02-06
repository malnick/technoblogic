---
layout: post
title: "puppet-webhook"
date: 2015-02-06 06:52:36 -0800
comments: true
categories: 
---
# puppet-webhook
Have you ever needed to implement a simple REST API call to another service after a puppet run or during? 

Well now you can!

This module contains a ```http``` type which can be ensureed to GET or POST. At the time of this writing the POST route has not been completed, however the GET route is implemnted as:

```ruby
http { 'the_route':
    ensure  => get,
    fqdn    => 'your.domain.com',
    port    => '6969',
}
```

This construction will essentially execute:

```
curl http://your.domain.com:6969/the_route
```

### Real world example
Ok great, now we have an access point to the ruby HTTP lib from Puppet. Now what? Well, eventually you'll be able to do something like this:

```ruby
http { 'my_api':
    ensure  => post,
    fqdn    => 'your.domain.com',
    port    => '6969',
    data    => {
        'my_key'        => 'some_value',
        'another_key'   => $::some_fact,
    }
    header  => 'application/json', # or maybe javascript? or whatever your hook expects...
}
```

Now that's a more complex example. What if all I want to do is execute a puppet run on my haproxy node after new nodes come up behind it?

Sure, there are a lot of ways we could accomplish this. I think the agreed upon way would be to use mCollective. mCollective is great since it rolls on Apache's ActiveMQ message bus. What that means is mCollective is **asynchronous** in messsaging. In other words, if we set up a webhook on our haproxy node to run ```puppet agent -t``` whenever a route recieves a GET request. However, we'd end up having a race condition on the puppet process itself; if puppet is already running when a new node comes up it will fail to implement the call to run puppet on the haproxy node since that call is synchronous.

mCollective's AMQ bus allows us to stick a message on the bus to run puppet if it can't execute puppet right away, like when the puppet process is already running and the lock file exists. 

So, the question remains: how do I execute a puppet run on our haproxy node, in order to get its fresh external resources (haproxy members) when new nodes come up? 

Well, we could have a run stage at the end of our role (for the new node which will be a haproxy member)  manifest for the class containing our ```http``` resource: 

Given a role of ```haproxy_member_backend_service```:

```ruby
class roles::haproxy_member_backend_service {
    stage { 'last':
        requires => Stage['main'],
    }

    #... a bunch of code

    class { 'profiles::update_loadbalancer':
        stage => 'last',
    }
}
```

...and a update_loadbalancer profiles like:

```ruby
class profiles::update_loadbalancer {
    
    http { 'update_loadbalancer':
        ensure  => get,
        port    => '6969',
        fqdn    => 'my.puppetmaster.com',
    }
}
```

We can implement a webhook profile that is included in our puppetmaster module (or role, if your puppetmaster doesn't need a lot of configuration like mine) like this (which uses the handy ```webhook::listener``` defined type) to build out a dynamically generated sinatra server:

```ruby
class puppetmaster::webhook {

    include webhook
    webhook::listener {'puppet':
        port => '6969',
        routes            => { 
            'kick_haproxy_app_internal'  => {
                'method'  => 'get',
                'command' => "su - peadmin -c 'mco puppet runonce -F role=haproxy_app_internal'"
            },
        }
    }
}
```

That ```webhook::listener``` builds a sinatra server at ```/usr/local/bin/webhook_puppet/```. It looks like this:

```ruby
require 'rubygems'
require 'rack'
require 'sinatra'
require 'webrick'
require 'logger'

# Global vars
LOGDIR              = File.expand_path(File.dirname(__FILE__)) + '/../logs'
SERVER_LOGFILE  = LOGDIR + '/server.log'
SESSION_LOG         = LOGDIR + '/session.log'

# Reset some envs
ENV['HOME']     = '/root'
ENV['PATH']     = '/sbin:/usr/sbin:/bin:/usr/bin:/opt/puppet/bin'
ENV['RACK_ENV'] = 'production'

# Implement an access log for robust logging of user info and access and git output
LOG = Logger.new(SESSION_LOG)
LOG.info("Setting session log at #{SESSION_LOG}")
LOG.info("Setting server log at #{SERVER_LOGFILE}")

# Server options
opts = {
    :Port               => 6969,
    :Logger             => WEBrick::Log::new(SERVER_LOGFILE, WEBrick::Log::DEBUG),
    :ServerType         => WEBrick::Daemon,
    :SSLEnable          => false,
}

class Server < Sinatra::Base


    get '/kick_haproxy_app_internal' do
        IO.popen("su - peadmin -c 'mco puppet runonce -F role=haproxy_app_internal'") do |output|
            output.each do |line| LOG.info(line.strip.chomp) end
        end
    end


    not_found do
        halt 404, 'You shall not pass! (page not found)'
    end
end

Rack::Handler::WEBrick.run(Server, opts) do |server|
    [:INT, :TERM].each { |sig| trap(sig) { server.stop } }
end
```

You can add as many routes as you'd like to the ```routes``` parameter in the ```webhook::listener``` define. It's great for quickly building and codifying your API infrastructure. For now, it only works with very simple things like 'I need to run this arbitrary command on a box on POST or GET', but I'm going to build it out with more complex routes as defautls such as:

* Accept a POST from jenkins with the ```environmnent```, ```role``` and ```version``` of a given build. Based on that post, update the hiera data as needed and re-run puppet on the box that is assigned the ```role``` in the given ```environmnent```. 

With a route like that you can setup a CI hook from your build environment in Jenkins (using any of the HTTP plugins for Jenkins) with Puppet very easily.

### ...back to the point ...



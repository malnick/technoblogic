---
layout: post
title: "Logging Analytics"
date: 2015-03-11 21:06:53 -0700
comments: true
categories: 
---
What’s the first line of action when dealing with a service that is down? Logs. 

You can ```ps ef```, ```netstat aux``` all day long but the big piece of information cake always lies in the log data. Log data carries the weight of information about your services, whether it’s a Spring Boot micro service powering a small piece of your backend platform or the NGINX and auth logs that convey what is happening on the opposite end of your application stack. 

Whatever the situation may be, logs are always the files we end up tailing to figure out what is happening and why. 

##Why tailing sucks
True story: ```grep -ir 404 * | wc -l``` or ```grep -irl 404 *``` or ```grep -r 404 * | sort | uniq -c```

Sure, you might have some good feedback from this. Sure, you can plug this into a tool like nagios to alert you when things hit the fan. 

But, it’s missing a critical piece: visualization. 

You can’t **see** the log data on a time-based graph; you can’t correlate it to large logging events based on message type, log path or node. You’re only aggregating a single log at a time, and the information

##How SRC:CLR Tracks Logging Data
At SRC:CLR we use Logstash, Redis, Elasticsearch and Kibana to capture log data from various services that we use including our Sping Boot micro service framework. The overall design looks like this:

![aggregation](http://michael.bouvy.net/blog/wp-content/uploads/2013/11/logstach-archi1.png)

Of course, this entire deployment is brought to you by Puppet Enterprise, and no blog post from me would be complete with out a [shameless plug for some new module we wrote to automate this it](https://github.com/sourceclear/puppet-kibana).

As you can tell, we’re using Kibana 4.0.0 (as of this post, 4.0.1 is out and IS amazing but we’re not using it quite yet). Kibana 4x ships with it’s own server, so there’s no need to frontend it with NGINX or Apache anymore. However, I highly recommend at minimum a local NGINX reverse proxy so you can DNS the node and connect on 80 or 443 if it’s public-facing. 

### Logstash Agent Configuration
In our role for a given node, lets say a backend node that would be running our micro services, I can simply add some logstash configuration:

```ruby
class roles::backend_services {
…
  # Logstash for services
    class { ::profiles::logstash::backend_services:
        redis_logstash_host => ‘our-redis-aggregator.ourdomain.com’,    
    }
…
# More configuration
```

And then our backend services profile for logstash, we do something like:

```ruby
class profiles::logstash::backend_services ($redis_logstash_host) { 

    class { 'logstash':
        package_url => 'https://download.elasticsearch.org/logstash/logstash/packages/debian/logstash_1.4.2-1-2c0f5a1_all.deb',
    }

    logstash::configfile { 'output_redis':
        content => template('profiles/logstash/output_redis.erb'),
        order   => 20,
    }
    logstash::configfile { ‘micro_service_one_input’:
        content => template(‘profiles/logstash/input_micro_service_one.erb’),
        order   => 10,
    }
    logstash::configfile { ‘micro_service_two_input’:
        content => template(‘profiles/logstash/input_micro_service_two.erb’),
        order   => 11,
    }
…
```

```$redis_logstash_host``` simply needs to be available in the variable namespace for the redis output template. 

When it comes to logstash, all the magic happens in those templates. For SRC:CLR, we roll with a few basic inputs and outputs in our logstash templates:

####Log Path Input

```ruby
# input_micro_service_one.erb
input {
    file {
        path => “/var/log/service_name/service_name*.log”
    }
}
```

####Redis Output

```ruby
output { 
    redis { 
        host => "<%= @redis_logstash_host %>" 
        data_type => "list" 
        key => "logstash" 
    }
}
```

####ElasticSearch Output

```ruby
output {
    elasticsearch {
        cluster => 'logstash' 
    }
}
```

####The Final ```logstash/conf.d/logstash.conf``` File

```ruby
input {
    file {
        path => [“/var/log/service_name/service_name*.log”]
    }
}

input {
    file {
        path => “/var/log/service_name/service_name*.log”
    }
}

output {
    redis {
        host => “our-redis-aggregator.ourdomain.com"
        data_type => "list"
        key => "logstash"
    }
}
```

So far, we’ve covered our log pipeline from ```micro_services_node -> redis_output```. What does the configuration for our redis aggregator look like? 

It starts, as usual, with the role:

```ruby
class roles::logging_aggregator  {
    # First, provision our ELK Stack
    class { ::profiles::elasticsearch::log_aggregator:}
    ->
    class { ::profiles::kibana::basic:}
    ->
    # The logstash node needs to be an indexer reading from redis, dumping into elasticsearch
    class { ::profiles::logstash::redis_indexer:}

    # Also, a basic redis instance
    include ::profiles::redis::basic   
}
```

As you can probably tell, we’re rolling the entire ELK stack and redis queue on a single node. We can do this because it’s on a c3.3xlarge AWS instance type with it’s own EBS attached volume of 100GB and the logging data is coming from a small-ish stack. 

Our logging volume at the time of this post is about 4GB per day, per environment (QA, Prod, etc..). Flushing your elasticsearch indices and backing them up is highly recommended. There are [various](https://github.com/imperialwicket/elasticsearch-logstash-index-mgmt) ways to do this sort of thing, but really the end goal is simple: get to 65% of EBS volume, then flush and back up to a persistent source. 

I recommend a datastore in your cluster such as MongoDB or tar.gz’s to S3. Either way, it’s amazing how much log data you can generate, and ours is a small infrastructure so your milage will vary. 

Eventually you’ll have to tackle the question: do I scale this vertically or horizontally. With elasticsearch in the mix the answer is simple: horizontally. ES has [“optimistic concurrency control”](http://www.elastic.co/guide/en/elasticsearch/guide/current/optimistic-concurrency-control.html) and is particularly well suited for clustering. 

For Redis, you’ll have to [make a personal decision](http://redis.io/topics/cluster-spec), but I typically prefer a vertical scale, which is why our aggregation node is a c3.2xlarge and will probably grow. 
 
###Logstash Aggregator Configuration
Finally, we have the logstash aggregator. I’m not going to dive into it’s elasticsearch or redis configuration since [both those](https://github.com/elastic/puppet-elasticsearch) tools are well [documented](https://forge.puppetlabs.com/fsalum/redis). Here, we'll focus on the logstash/redis aggregator configuration.

I will however note the importance, again, of using an EBS volume for your ES data!

From the role profile given above, lets take a look at ```::profiles::logstash::redis_indexer```:

```ruby
class profiles::logstash::redis_indexer { 

    class { 'logstash':
        package_url => 'https://download.elasticsearch.org/logstash/logstash/packages/debian/logstash_1.4.2-1-2c0f5a1_all.deb',
    }

    # This template contains everything we need to run the indexer on a single host
    logstash::configfile { 'redis_indexer':
        content => template('profiles/logstash/redis_indexer.erb'),
        order => 10,
    }
}
```

Where the redis_indexer.erb looks like this:

```ruby
input {

    redis {
        host => "127.0.0.1"
        data_type => "list"
        key => "logstash"
        codec => json
    }
}
output {
    elasticsearch { 
        host => "localhost" 
    }
    stdout { 
        codec => rubydebug 
    }
}
```

You might notice the stdout output in that. The stdout is great for debugging stuff. When you run ```logstash service start``` it’ll startup as a daemon and you can ```tail -f /var/log/logstash.log``` but I prefer to run it in the foreground when I’m hooking everything up to see all the pretty colors and to drop it into debug mode. 

To do this I execute on both the nodes I’m pulling logs from and the log aggregator:

```/opt/logstash/bin/logstash -f /etc/logstash/conf.d/logstash.conf —debug```

Once this pipeline is executed you can go ahead and open ```our-redis-aggregator.ourdomain.com:5601``` in your browser and start making some fancy graphs:

![one](https://s3.amazonaws.com/srcclr-public/Screen+Shot+2015-03-11+at+10.15.51+AM.png)
![two](https://s3.amazonaws.com/srcclr-public/Screen+Shot+2015-03-11+at+10.16.26+AM.png)

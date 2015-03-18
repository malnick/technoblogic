---
layout: post
title: "jenkins-puppet-CI"
date: 2015-03-17 17:05:41 -0700
comments: true
categories: 
---
# SRC:CLR Deploy - Merge-to-Master -> Jenkins -> Puppet
At SRC:CLR we used to use Opsworks to deploy our code pipeline. Opsworks is great but is overloaded with a lot of extra things that we don't need or want. It also doesn't allow us to fully open our code pipeline to outside applications in the way we wanted. 

In order to give our devs the easist way to deployment, we setup a pipeline from merge-to-master to deploy that encompasses the peer review process, java unit tests, and of course Puppet.

If you don't want to read the post, we've open sourced the code for [this webhook](https://github.com/malnick/jenkins-puppet-webhook.git). 

## The 10,000 Mile View

1. A developer submits a PR to merge to master from a dev branch
1. Her peers review this PR and accept the merge to master
1. Jenkins watches this repo, and starts a build on that branch
1. If all tests pass, the jar file is sent to s3: ```service-$version.jar```
1. A post build shell script runs that sends a POST with data about the buid to our puppet master
1. The webhook on the master accepts this POST and uses the data to:
  1. Update hte version of the service in Hiera
  1. Update the git repo where the data file that tracks versions exists (in this case the puppet control repo with hiera data)
  1. Run mCollective to update all nodes matching the role which the service runs on
  1. The node(s) check in with the master, and diff the versino in the title of the S3 resource for the service jar file
  1. See the version has changed (since we updated it in hiera) the agent pulls down hte new jar file with version $version
  1. The agent restarts the services

## The More Intimate View 
This sinatra hook sits on a Puppet Master and listens for POSTs on :1015, when hit with a payload it updates the version number of a service in Hiera data and executes a mCollective call to run puppet on the node with a matching $::role value. 

This is great when used in conjunction with [puppet-s3](https://github.com/malnick/puppet-s3) provider or something similar where you can classify the resrouce like 

```ruby
s3 { "/path/to/service-${version}":
  ...
```

Then, using our webhook or a modified version of it, you can have a one click deploy in Jenkins since this hook will update the version in Hiera data that the ```s3``` resource is diff'ing from and execute mCollective to run puppet on the node matching a specific role - i.e., the role that classifies the node running the service being built by jenkins and pulled down by the ```s3``` resrouce. 

### How it's done...
Lets say you wanted to use the [open sourced](https://github.com/malnick/jenkins-puppet-webhook.git) webhook and integrate it with your environment, here's what you need to know:

#### A few assumptions: 

1. The payload from Jenkins, or whatever tool you're using to hit this hook, will pass the following parameters:

```json
{
  "service":      "your_name_in_hiera_data",
  "environment":  "your_environment",               # qa or production?
  "version":      "service_version_being_deployed", # you'll want to dynamicaly generate this in jenkis
  "role":         "role_of_node_in_puppet"
}
```

1. The Hiera data key matches the following pattern:

```yaml
# Overlay with vars from JSON
${service_name}_version_${environment}: '1.2.1'
# A real-world example
myservice_version_qa: '1.2.1'
myotherservice_version_qa: '1.4.1'
someservice_version_production: '0.5.1'
myservice_version_production: '1.1.0'
...
```

You can override this in the options you pass via the JSON POST with the key ```key```.

1. You'll fork this repo, and update the ```data_file``` and maybe the ```key``` values in ```lib/options.rb```:

```ruby
module Update
  class Options

    attr_accessor :config

    def initialize(options)

      LOG.info("##### Parsing Options #####")

      @config         = Hash.new

      # Required data from POST
      @config[:environment]    = options['environment']   # qa or production etc
      @config[:version]        = options['version']       # The version to write to the data file
      @config[:service]        = options['service']       # The service name
      @config[:role]           = options['role']          # The role for the nodes to update via mCollective

      # Optional data from POST
      @config[:key]            = options['key']             || "#{@config[:service]}_version_#{@config[:environment]}"
      @config[:git_repo]       = options['git_repo']        || 'git@github.com:malnick/puppet-control'
      @config[:git_repo_dir]   = options['git_repo_dir']    || '/tmp/control'
      @config[:data_file]      = options['data_file_path']  || "#{@config[:git_repo_dir]}/global.yaml"

      LOG.info("##### Setting configuration #####")
      @config.each do |k,v|
        LOG.info("#{k}: #{v}")
      end
    end
  end
end
```

1. You're using a ```$::role``` fact. I roll in AWS, so everything is classified based on ```$::role```. This webhook won't be able to run puppet on the node running your service you just updated the version for until you modify this code or get yourself a role face.
 
### Deployment Pattern

1. Clone the repo to your pupetmaster and make the above suggested changes to make it work with your deployment

```bash
git clone git@github.com:malnick/jenkins-puppet-webhook.git
```

1. Turn it on:

```bash
bin/webhook start
# Should come up on :1015
```

1. Have a post-run stage in your jenkins build for a given service that executes something akin to the following:

```sh
# Assuming you're running this from $WORKSPACE in jenkins, your paths will vary as well as your method of obtaining the version off the build.
VERSION=$(echo service/target/service-*.jar | cut -d- -f2 | cut -d. -f1,2,3)

# Curl this webhook, which should be on the Puppet Master
curl \
  -X POST \
  -d@- \
  puppet.myorg.com:1015/deploy <<EOF
{
  "service":     "myservice",
  "version":     "$VERSION",
  "environment": "qa",
  "role":        "qa_services_migration"
}
EOF
```

### Kick off a build....
This should implement the following chain:

1. Build is executed on jenkins
1. If successful the build drops the new versioned jar or zip file or whatever in S3: ```myservice-0.2.5.jar```
1. If successful the shell post-run is executed, running the above script that gets the new $version and POSTs to our webhook on the puppet master
1. The webhook updates hiera data with the correct value for the updated version
1. The webhook updates git to ensure that jenkins owns our versioning
1. The Webhook executes an MCO call to run puppet on the node running this service based on the ```$::role``` fact
1. The nodes matching the ```$::role``` get the updated version in hiera data and match that against the ```s3``` resource in that:

```ruby
...
s3 { "${basedir}/${service}-${version}.jar":
    ensure            => present,
    source            => "/my_bucket/${service}-${deploy_stage}/${service}-${version}.jar",
    access_key_id     => $access_key_id,
    secret_access_key => $secret_access_key,
    require           => File[$basedir],
}
...
```

Where ```$version``` is derived from 

```ruby
$service = 'my_service'
$version = hiera(my_service_version_qa)
...
```

## Some Closing Remarks... or why this is rad
Your devs should never have to worry about depoying code, they have enough to worry about in writing it. The pipeline that is built around deployment should be mind numbingly simple for them to implement. Merge-to-master is scary for a lot of reasons. Automating the updating of values in Hiera is scary for a lot of reasons. At the end of the day however, those are my problems and not the developers. My job is to make efficient pipelines for our product, and the release pipeline is the purest incarnation of that. We think this is pretty rad, and if you want to play along and fork our public repo and submit some PR's we'd love to hear from you.  


---
layout: post
title: "Continous Integration Hooks with r10k &amp; Puppet"
date: 2014-05-04 07:47:05 -0700
comments: true
categories: 
---
A week ago I was modifiying a webhook to run r10k on push to a git repository. The goal here was to sync up r10k everytime a push was made to the repo. However, in doing so I found that the [current](https://github.com/acidprime/r10k/blob/master/templates/usr/local/bin/webhook.erb) hook didn't take advantage of deploying a specific puppet environmnet, and instead runs a full r10k sync across all topic branchs and thus all puppet environments.

I figured the first place to start was modifying the ['post'](https://github.com/acidprime/r10k/blob/master/templates/usr/local/bin/webhook.erb#L35) method:

{% codeblock lang:ruby %}
post '/payload' do
      #protected!
      deploy()
    end
{% endcodeblock %}

 to parse the json sent by git (in this case I was integrating with gitlab) for the [ref branch](http://demo.gitlab.com/help/web_hooks). So the 'post' hook now looks like [this](https://github.com/malnick/r10k/blob/master/templates/usr/local/bin/webhook.erb#L52):

{% codeblock lang:ruby %}
post '/payload' do
    #protected!
    request.body.rewind  # in case someone already read it
    data = JSON.parse request.body.read
    branch = data['ref'].split("/").last
    "ref branch: #{branch}"
    #deploy(refs)
end
{% endcodeblock %}

So the #branch effectively is our puppet environment that we want to pass to the r10k mcollective agent so we can deploy a specific puppet enviro and not sync across all topic branches/enviros. This will make it lightweight.

However, I ran into a blocker in the mcollective r10k agent itself. I want to pass this argument to it so I can sync all r10k nodes at once from this hook based on the ref branch the current r10k [agent](https://github.com/acidprime/r10k/blob/master/files/agent/r10k.rb#L28) does not accept any arugments and only syncs across all topic branches using the 'syncronize' method.

In order to pass this ref branch in and leverage 'r10k deploy environmnet #{topic_branch}' as I'm attempting here the agent will need to be modified to parse the argument.

[Zach's current r10k agent](https://github.com/acidprime/r10k/blob/master/files/agent/r10k.rb#L28) is pretty good, so we'll stick to modifying that (at this point I handed over the agent writing to a colleague Andrew Brader since I was sent to a training site and he had a week/time to modifying the mco agent):

{% codeblock lang:ruby %}
     def run_cmd(action,path=nil)
        output = ''
        git  = ['/usr/bin/env', 'git']
        r10k = ['/usr/bin/env', 'r10k']
        case action
        when 'push','pull','status'
          cmd = git
          cmd << 'push'   if action == 'push'
          cmd << 'pull'   if action == 'pull'
          cmd << 'status' if action == 'status'
          reply[:status] = run(cmd, :stderr => :error, :stdout => :output, :chomp => true, :cwd => path )
        when 'cache','environment','module','synchronize','sync', 'deploy_all'
          cmd = r10k
          cmd << 'cache'       if action == 'cache'
          cmd << 'synchronize' if action == 'synchronize' or action == 'sync'
          cmd << 'environment' if action == 'environment'
          cmd << 'module'      if action == 'module'
          cmd << 'deploy' << 'environment' << '-p' if action == 'deploy_all'
          reply[:status] = run(cmd, :stderr => :error, :stdout => :output, :chomp => true)
        end
    end
{% endcodeblock %}

In order to parse the topic branch from the hook we need to add a method, which Andrew did [here](https://github.com/abrader/r10k/blob/master/files/agent/r10k.rb#L59):

{% codeblock lang:ruby %}
      def deploy_only_cmd(r10k_env=nil)
        output = ''
        r10k = ['/usr/bin/env', 'r10k']
        cmd = r10k
        cmd << 'deploy' << 'environment' << r10k_env << '-p'
        reply[:status] = run(deploy_only_cmd, :stderr => :error, :stdout => :output, :chomp => true)
      end
{% endcodeblock %}

### Testing the new hook & agent

... to be updated shortly... 


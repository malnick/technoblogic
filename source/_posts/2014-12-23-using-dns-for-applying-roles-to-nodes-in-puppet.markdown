---
layout: post
title: "DNS-based role classification"
date: 2014-12-23 16:49:37 -0800
comments: true
categories: 
---
The first place you'd probably look for developing a role-based hiera layer is probably a fact-based role. Facts are great, they allow you to execute code on a node and generate dynamic information about your infrastructure. You could go ahead and do this very easily if you have solid domain naming mechanisms. 

For example, your load balancer might always start with ```lb-p-dc.domain.prd.int``` and your app nodes might always start with ```app-p-dc.domain.prd.int``` or something like that. 

But in reality, domain names are never really this elegant. So the reality is you need to have a better, more resolute way to figure out what role each node has. 

You could, at this point, go the route of external facts. External facts are cool because they can be provisioned via a pxe-boot script as a simple txt file with key value pairs. However, now you have to manage and ensure this **very important** piece of infrastructure code is in place properly on each node. If someone deletes this fact, you have to have some configuration management magic to ensure it gets put back in place since external facts don't pluginsync. 

### DNS-based role classification
You can however implement some DNS magic. DNS has specific resources that include more than just a mapping of IP addresses to domains. Domains can have TXT resources associated with them. So let's assume your load balancer, ```lb-p-dc.domain.prd.int```, has a TXT resource associated with it in DNS. Now we can write a fact that looks up that TXT resource. 

That fact might look something like:
```ruby
require 'resolv'
Facter.add('role') do
	setcode do
		# Get hostname based on fqdn fact
		hostname = Facter.value(:fqdn)
		# Get a new DNS resolver object pointed at our nameserver i
		stupid = Resolv::DNS.new # Defaults to /etc/resolv.conf on linux envs
		# Get a TXT DNS resource for the host
		this = stupid.getresource(hostname, Resolv::DNS::Resource::IN::TXT)
		# .strings is the value of the txt resource and it's an array since you can have many txt resources
		this.strings.each do |r|
			# Get the role txt resource
			if r =~ /^role/
				# Split it on = for the last part which is the value of the role
				role = r.split('=').last
			end
		end
		# If role never got set it's because /^role never matched, so let's set this to unknown
		unless role
			role = 'unknown'
		end
		# Return the role
		role
	end
end
```

Hey, that's pretty neat. So this little fact executes on the node on agent runs. Does a lookup in DNS for the TXT resource. Finds that TXT resource and returns the role type. If no TXT resource that matches /^role/ is found, it returns an 'unknown' role. 

Now you can implement that ```role/%{::role}``` layer in hiera like you always wanted! Yay!

### Why this isn't secure
Buzz kill ahead!

This fact is only somewhat secure. Since this isn't a secure fact, like clientcert, it can be overridden on the command line like this:

```ruby
FACTER_role=application puppet agent -t
```

Now, whoever got on your subnet with your puppet master can easily pull down your application node's configuration. SSH keys, private keys, whatever other private information you might have as part of the configuration for this node.

(Ok, maybe not quite as simple as that if you don't auto-authenticate your nodes. However, if one node in the infrastructure that is authenticated to the Puppet Master CA get's taken over a smart attacker could do a puppet run with the role type for every other node in the infrastructure and get a lot of data out of it.) 

### The fix
The best way to fix this issue is to get the DNS TXT resource using a secure fact like $::clientcert. Then pass this fact into a function that will execute on the master to do the DNS lookup for you.

For example, your function instanciation migth look like this:

```ruby
class MyClass (
	$role = role_resolver($::clientcert),
){
...
```

Then your function ```role_resolver()``` might look like this:

```ruby
require 'resolv'
module Puppet::Parser::Functions
	newfunction(:role_resolver, :type => :rvalue) do |args|
		hostname = args[0]
		stupid = Resolv::DNS.new
		this = stupid.getresource(hostname, Resolv::DNS::Resource::IN::TXT)
		this.strings.each do |r|
			if r =~ /^role/
				role = r.split('=').last
			end
		end
		unless role
			role = 'unknown'
		end
		role
	end
end
```

Now, since you're using a trusted, secure fact $::clientcert you are most certain that your lookup in DNS will be for the node that is checking in and nothing else. This is both secure as well as a fast, trusted way to get role classification from your current DNS system.

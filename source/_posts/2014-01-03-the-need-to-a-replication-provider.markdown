---
layout: post
title: "The Need for a Replication Provider"
date: 2014-01-03 09:05:51 -0800
comments: true
categories: [puppet,ruby,providers]
---
###Why we need a replication provider for puppet
I've been using puppet for over a year now. I started using it at the request of a friend who wanted a simple, one-liner command to boot his e-commerce platform on Vagrant VM's for dev and eventually production. I was impressed by the simplicity, the software defined server-state was easy to create through the elegant package, resource, service workflow. It wasn't very long that we found other more advanced needs for Puppet. 

One of these needs was booting multiple MySQL server slaves on a single host machine to replicate various MySQL masters. The masters were any one of the customers currently using this e-commerce platform. The distributed nature of the servers and the cost-benefit of running a single slave server (a beefy host nonetheless) for all of them presented a few challenges. 

First off, nobody wants to be a sysadmin. This company was small in terms of manpower and everyone was already in a DevOps role, but who wants to sit around running "CHANGE MASTER TO"... all day? Not your python dev that's for sure. So we decided it was best to build out a Puppet module that can run on the slave and master hosts that would:

1. Boot multiple MySQL slaves on one host
2. Dump the master MySQL DB and scp to the slave (once the slave was provisioned)
3. Import the scp'ed DB to the slave and start replication from the correct binlog position

Simple right? Yeah... right. 

Let's cut the chase: how many lines of puppet code did it take for me to write a unique mysql slave instance onto a host? 

167

For each slave I needed to provision:

* /var/lib/mysql_instance#
2. /var/log/mysql_instance#
3. /etc/mysql_instance#
4. /etc/mysql_instance#/my.cnf
5. Customize that my.cnf for the instance

Which looks like standard Puppet fun:

{% codeblock lang:ruby slave.pp %}

# All SQL instances get their own directories:
file { "/var/lib/mysql${slave_server_id}":
		ensure        => directory,
		recurse        => true,
		owner        => 'mysql',
		group        => 'mysql',
		}
file { "/var/log/mysql${slave_server_id}":
		ensure        => directory,
		recurse        => true,
		owner        => 'mysql',
		group        => 'mysql',
		}

# All SQL instances get their own /etc and cnf:
file { "/etc/mysql${slave_server_id}":
		ensure        => directory,
		recurse        => true,
		owner        => 'mysql',
		group        => 'mysql',
		}                
file { "my${slave_server_id}.cnf":
		ensure         => file,
		path        => "/etc/mysql${slave_server_id}/my${slave_server_id}.cnf",
		mode        => 0644,
		owner         => 'mysql',
		group         => 'mysql',
		content        => template('replicate/my.cnf.multi.erb'),
		require        => File["/etc/mysql${slave_server_id}"],
		}

{% endcodeblock %}

Then I needed to boot a DB with the datadir, and from that point on it was, well, you know, a bash script basically with a million exec statements:

{% codeblock lang:ruby slave.pp %}
# Prepare DB:
exec { "${name} Initialize Database":
		path        => '/usr/bin:/bin',
		command        => "mysql_install_db --user=mysql --datadir=/var/lib/mysql${slave_server_id}",
		require        => [File["/var/lib/mysql${slave_server_id}"],File["/var/log/mysql${slave_server_id}"]],
		}

# Start SQL instance:
exec  { "$ {name} Spin up SQL Server" :,ca
		path        => '/bin:/usr/bin:',
		command        => "mysqld_safe --defaults-file=/etc/mysql${slave_server_id}/my${slave_server_id}.cnf &",
		require        => [Exec["${name} Initialize Database"],File["my${slave_server_id}.cnf"]],
		}        

# Execute CHANGE MASTER TO - TODO: add if conditional for with password mysql commands
# Grant slave user priviledges if without password:

if $mysql_root_password == "false"{         
		exec  { "$ {name} grant privledges" :,ca
				command                => "$mysql_cmd_root_without_pwd $mysql_socket --execute=\"GRANT REPLICATION SLAVE, REPLICATION CLIENT ON *.* TO '$mysql_replication_user'@'$slave_ip' IDENTIFIED BY '$mysql_replication_password';\"",
				Require                 =>  Exec [ "$ {name} Spin up SQL server" ],ca
				}

		exec {"stop ${name}":
				command                => "$mysql_cmd_root_without_pwd $mysql_socket --execute=\"STOP SLAVE;\"",
				require                => Exec["grant ${name} privledges"],
				}
		exec {"master info for ${name}":
				command        => "$mysql_cmd_root_without_pwd $mysql_socket --execute=\"CHANGE MASTER TO MASTER_HOST='$master_host',MASTER_USER='$mysql_replication_user',MASTER_PASSWORD='$mysql_replication_password',MASTER_LOG_FILE='$master_log_file',MASTER_LOG_POS=$master_log_pos;\"",
				require        => Exec["stop ${name}"],
				}
		exec {"start ${name} instnace on server":
				command                => "$mysql_cmd_root_without_pwd $mysql_socket --execute=\"START SLAVE;\"",
				require                => Exec["master info for ${name}"],
				}
		exec  { "$ {name} restart server" :,ca
				command        => "/usr/bin/mysqladmin -S /var/run/mysqld/mysqld${slave_server_id}.sock stop;
										/usr/bin/mysqladmin -S /var/run/mysqld/mysqld${slave_server_id}.sock start",
				require        => Exec["start ${name} instnace on server"],
				notify        => Replicate::Import["Import ${import} onto ${name}"],
				}
   }
{% endcodeblock %}

But WHAT IF THEY'RE CRAZY AND HAVE NO PASSWORD????

I made other commands for that too...

{% codeblock lang:ruby slave.pp %}

if $mysql_root_password != "false"{         
exec  { "$ {name} grant privledges" :,ca
		command                => "$mysql_cmd_root_with_pwd $mysql_socket --execute=\"GRANT REPLICATION SLAVE, REPLICATION CLIENT ON *.* TO '$mysql_replication_user'@'$slave_ip' IDENTIFIED BY '$mysql_replication_password';\"",
		Require                 =>  Exec [ "$ {name} Spin up SQL server" ],ca
		}

exec {"stop ${name}":
		command                => "$mysql_cmd_root_with_pwd $mysql_socket --execute=\"STOP SLAVE;\"",
		require                => Exec["grant ${name} privledges"],
		}
exec {"master info for ${name}":
		command        => "$mysql_cmd_root_with_pwd $mysql_socket --execute=\"CHANGE MASTER TO MASTER_HOST='$master_host',MASTER_USER='$mysql_replication_user',MASTER_PASSWORD='$mysql_replication_password',MASTER_LOG_FILE='$master_log_file',MASTER_LOG_POS=$master_log_pos;\"",
		require        => Exec["stop ${name}"],
		}
exec {"start ${name} instnace on server":
		command                => "$mysql_cmd_root_with_pwd $mysql_socket --execute=\"START SLAVE;\"",
		require                => Exec["master info for ${name}"],
		}
exec  { "$ {name} restart server" :,ca
		command        => "/usr/bin/mysqladmin -S /var/run/mysqld/mysqld${slave_server_id}.sock stop;
								/usr/bin/mysqladmin -S /var/run/mysqld/mysqld${slave_server_id}.sock start",
		require        => Exec["start ${name} instnace on server"],
		notify        => Replicate::Import["Import ${import} onto ${name}"],
		}
}
{% endcodeblock %}

SO MANY COMMANDS!!! 

Any post where you need to exclaim this much in caps says a lot about the code you're writing right? Right. That's a principle.

So this is where providers come in. In Puppet you could write this code to do this work. And I mean, that's what Puppet is for right? Provisioning. Yes,
that's true, but this isn't really* Puppet code, this is a bunch of exec statements, which is basically a bash script. This isn't very economical, it's 
not very elegant, it's a lot of coding. Would it be nice if we could just:

{% codeblock lang:ruby %}
replicate_server { 'master':
	hostname 			=> $::hostname,
	mysql_repl_password => "1234",
	mysql_repl_user   	=> "repl",
	server_id     		=> 21,
}
{% endcodeblock %}

... in our provisioning manifest and not have to write this crazy defined type for each SQL slave? Because right now as it stands my slave.pp for the replicate class is 
167 lines. There are, umm, a lot of other subclasses there to enable this to work. Like the master.pp, my params, some crap about dumping DB's and blowing out
the old ib_log files and holy shit that's a lot of puppeteering. 

I would much rather have a provider that's pure ruby which can provision this for me. (WARNING PSUDO PROVIDER COMING).

Something like this for the commands (of which, as you can see from above, are crazy nuts since it's puppet telling bash telling mysql telling mysql instance...):

{% codeblock lang:ruby  / modules / replicate / lib / puppet / provider / replicate / replication.rb %}
Puppet::Type.type(:replicate).provide(:replication) do
        
        #confine :osfamily => [:debian, :redhat]

# Commands 
        
        commands         :mysql             => "/usr/bin/mysql"                
        commands         :mysqladmin        => "/usr/bin/mysqladmin"
        commands         :service           => "/etc/init.d/mysql"
{% endcodeblock %}

Ahhhh, ok that' better than:

{% codeblock lang:ruby slave.pp %}
$mysql_cmd_root_without_pwd = "/usr/bin/mysql --user=$mysql_root_user --database=$mysql_database --host=$mysql_root_local_host"
$mysql_cmd_root_with_pwd    = "/usr/bin/mysql --user=$mysql_root_user --database=$mysql_database --host=$mysql_root_local_host --password=$mysql_root_password"
$mysql_cmd_repl_with_pwd    = "/usr/bin/mysql --user=$mysql_replication_user --database=$mysql_database --host=$mysql_root_local_host --password=$mysql_replication_password"
$mysql_cmd_repl_slave       = "/usr/bin/mysql --user=$mysql_replication_user --database=$mysql_database --host=$mysql_master_ip_address --password=$mysql_replication_password"
{% endcodeblock %}

Then we could write a out a single provider and corresponding type which defines the instance based on "roles" of "master" or "slave". The provider would figure out if this host 
already has a master or slave instance running on it, which my replication module ... does not do .. which, you guessed it, could break a lot of stuff if you run it twice. 

Which brings us to...

#### A provider, when done correctly is idempotent!

... and that's not all, if the replication provider is built-in we can use 'puppet resource replicate' on the command line for all things replication related. 

Let's say we wanted to query the master SQL instances
on this host, we could:

``` 
$ puppet resource replicate role=master 
```

and get something like:

```
replicate {"master":
	ensure => present,
	}
```

if this host has a master instance running on it. 

This is of course provided by the magic of self.instances in the provider. Here's some more psudo ruby of what that might look like:

{% codeblock lang:ruby Psudo-Provider %}
def self.instances
	get_master_instances()
end

def self.get_master_instances()
	desc "get master info"
	mstr_info = {}
	begin
			output = `mysql -NBe "show master status"`.split(" ").collect(&:strip)
	rescue Puppet::ExecutionFailure => e
				raise Puppet::Error, "Oh no, execution of 'show master status' for MySQL failed"
	end

	mstr_info[:ensure] = output == nil ? :absent : :present
	mstr_info[:log_position] = output[1].empty? ? nil : output[1]
	mstr_info[:binlog_do_db] = output[2].empty? ? nil : output[2]
	#mstr_info[:provider] = :ruby
	mstr_info[:name] = :binlog_do_db
	mstr_info
end
{% endcodeblock %}

And return the instances.

Now the provider would have to be written with the duel nature of master/slave replication in mind. Unless you want to have multiple providers, one for each of the roles of master or slave. 
However I think it would be easier to write it into a single provider that discriminates based on the 'role' parameter in the type. 

But I digress, let's get back to the meat of this thing. 

The awesome thing about having a provider do this work for us is that we don't have to worry about all the module-related debugging, platform dependancies and none-idempotent nature of a standalone replication
module (*cough .. my replication module, which I did not write with idempotentcy in mind). We have better integration with puppet through the use of 'puppet resource' - it inherently is far more extendable than a standalone module  and integrates well with most puppet platform distributions. 
The coding for it is far more economical, and we don't have a psudo-bash script written into our Puppet code via exec! 

You get to write your puppet code to do puppet stuff and let the provider/type ruby magic do it's work for you. It's a win win, now all we need to do is actually write this thing... 


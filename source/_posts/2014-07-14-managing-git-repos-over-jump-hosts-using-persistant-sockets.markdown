---
layout: post
title: "Managing Git Repos over Jump Hosts using Persistant Sockets"
date: 2014-07-14 07:09:09 -0700
comments: true
categories: 
---
I was recently helping a customer who had a somewhat complicated git workflow to production. All their Puppet code was in a locally accessible Gitlab server which was used by all the Automation dev's to develop, test and push to. 

However, their integration and production environments were located behind a jumphost which also required a custom VPN connection. 

The problem was that this deployment relied on [r10k](https://github.com/adrienthebo/r10k) and the Puppet master needed access to the Gitlab server to create the local environments in both integration and eventually production. 

Enabling a streamlined process to move the Gitlab codebase from our dev area into the corralled VM behind the jumphost was needed. 

This workflow involves several steps:

1. Connect NA Client VPN to Jumphost
2. SSH to Jumphost and enter auth credentials
3. SSH into yum repo server behind jumphost
4. Enter in yum repo auth credentials
5. scp your data - many ways to skin that cat, all are somewhat complicated

## Automate with persistant SSH sockets
I decided to write a SSH script which will do this, and I wanted to ensure we didn't fall into 'password' hell and have to enter in a new password every time. I had heard you could do this by using the 'ControlMaster' SSH param in SSH_config, open a persistant socket, and reuse it as needed. If I could enable this over a jumphost was another question but I gave it a shot. 

1. Create a persistant socket to jumphost with tunnel on localhost through the jumphost, pushing traffic from port 22 -> 5000

        ssh -o 'ControlMaster auto' -o 'ControlPath ~/.ssh/jump.sock' -N -f -L 5000:[git_repo_ip]:22 root@[jumphost_ip]

2. Create a direct persistant socket to the integration or production Gitlab server on localhost tunnel

        ssh -o 'ControlMaster auto' -o 'ControlPath ~/.ssh/git.sock' -N -f root@localhost -p 5000

3. CP arbitrary documents easily

	scp -o 'ControlPath ~/.ssh/yum.sock' -P 5000 $filepath root@localhost:/tmp/

4. SSH (no password required once socket is created!)

        ssh -S ~/.ssh/yum.sock root@localhost -p 5000

5. To destroy the sockets you need to do the yum repo first and jump second

        ssh -S ~/.ssh/yum.sock -O exit root@localhost && ssh -S ~/.ssh/jump.sock -O exit root@172.20.132.3

## A quick script
Now that I can create persistant sockets I wrote a script to SSH into the local git, run ```rake::restore```, scp the backup to my host, scp the backup from my host into the integration git over the jumphost connection, and run rake::restore.

1. Check to ensure I'm connected to the correct VPN Gateway

	{% codeblock lang:ruby %}
	test -e ~/.ssh || { echo "Create an ssh dir"; exit 1; }

	VPNENV=`echo $(naclient status | awk 'NR==4' | cut -d: -f2)`
	DALLAS="d4p4"
	LABGIT="10.144.36.226"
	INTGIT="172.24.3.246"
	JUMPHOST="172.20.132.3"

	if [ "$VPNENV" == "$DALLAS" ]
	then
		echo "Connected to $VPNENV"
	{% endcodeblock %}

2. Build the sockets

	{% codeblock lang:ruby %}
	echo "Connecting to git in labs:"
	ssh -o 'ControlMaster auto' -o 'ControlPath ~/.ssh/labgit.sock' -N -f root@$LABGIT
	echo "Connecting to jumphost:"
	ssh -o 'ControlMaster auto' -o 'ControlPath ~/.ssh/jump.sock' -N -f -L $PORT:$INTGIT:22 root@$JUMPHOST
	echo "Connecting to git in integration:"
	ssh -o 'ControlMaster auto' -o 'ControlPath ~/.ssh/intgit.sock' -o 'UserKnownHostsFile /dev/null' -N -f root@localhost -p $PORT	
	{% endcodeblock %}

3. Use the sockets for SSH and SCP

	{% codeblock lang:ruby %}
	ssh -S ~/.ssh/labgit.sock root@$LABGIT gitlab-rake gitlab:backup:create
	ssh -S ~/.ssh/labgit.sock root@$LABGIT "$(typeset -f); stagelatest"
	{% endcodeblock %}

A note before moving on about the 'stagelatest' function. I had a complicated command that I didn't want to toss into the SSH line, so I wrote a fuction and ran the ```$(typeset -f)``` command to make that function available on the remote SSH shell executing the commands. The function looked like this:

	{% codeblock lang:ruby %}
	stagelatest () {
	LATESTBAK=$(ls -t /var/opt/gitlab/backups/ | head -1)
	rm /tmp/1111111111_gitlab_backup.tar
	ln -s /var/opt/gitlab/backups/$LATESTBAK /tmp/1111111111_gitlab_backup.tar
	}
	{% endcodeblock %}

Continuing with our SCP and SSH commands:

	{% codeblock lang:ruby %}
	scp -o 'ControlPath ~/.ssh/labgit.sock' root@$LABGIT:/tmp/1111111111_gitlab_backup.tar /tmp/
	scp -o 'ControlPath ~/.ssh/intgit.sock' -P $PORT /tmp/1111111111_gitlab_backup.tar root@localhost:/var/opt/gitlab/backups
	ssh -S ~/.ssh/intgit.sock root@localhost -p $PORT BACKUP=1111111111 gitlab-rake gitlab:backup:restore <<< yes
	{% endcodeblock %}

## The final script
My final script includes a cleanup() function that is exectued via ```trap``` and at the end of the script on a good run. Cleaning up the sockets and ensuring nothing is left is always good practice. 

I also modified my SSH commands to not use the known_hosts file. This way I could reuse the tunnle on localhost:5000 to other jumphost connections inside the corralled integration or production environments. Had I used the known_hosts file every time and not pipped it to ```/dev/null```, everytime I reused localhost:5000 to tunnel to a new server behind the jumphost the public key would change and SSH would think someone is trying to do something funny. 

I also include some more logic to really make sure that the rake::restore should run on the integration/production gitlab server. Nerver hurts to double check!

{% codeblock lang:ruby %}
#!/bin/bash
cleanup () {
	echo "Cleaning up sockets and exiting"
	test -e ~/.ssh/labgit.sock && ssh -S ~/.ssh/labgit.sock -O exit root@$GITLAB
	test -e ~/.ssh/intgit.sock && ssh -S ~/.ssh/intgit.sock -O exit root@localhost
	test -e ~/.ssh/jump.sock && ssh -S ~/.ssh/jump.sock -O exit root@$JUMPHOST
	exit $@
}
trap cleanup SIGHUP SIGINT SIGTERM

stagelatest () {
	LATESTBAK=$(ls -t /var/opt/gitlab/backups/ | head -1)
	rm /tmp/1111111111_gitlab_backup.tar
	ln -s /var/opt/gitlab/backups/$LATESTBAK /tmp/1111111111_gitlab_backup.tar
}

getport () {
	PORT=$(( $RANDOM % 1000 + 5000 ))
	CHECK=$(netstat -an |grep LISTEN | egrep "[.:]${PORT}\s" > /dev/null; echo $?)
	while [[ "$CHECK" == 0 ]]
	do
		echo "Port: $PORT is in use by another process, choosing another port."
		PORT=$(( $RANDOM % 1000 + port ))

		CHECK=$(netstat -an |grep LISTEN | egrep "[.:]$PORT\s" > /dev/null; echo $?)
	done
	echo "Setting port to $PORT"
}
getport

test -e ~/.ssh || { echo "Create an ssh dir"; exit 1; }

VPNENV=`echo $(naclient status | awk 'NR==4' | cut -d: -f2)`
DALLAS="d4p4"
LABGIT="10.144.36.226"
INTGIT="172.24.3.246"
JUMPHOST="172.20.132.3"

if [ "$VPNENV" == "$DALLAS" ]
then
	echo "Connected to $VPNENV"

	echo "Connecting to git in labs:"
	ssh -o 'ControlMaster auto' -o 'ControlPath ~/.ssh/labgit.sock' -N -f root@$LABGIT 
	echo "Connecting to jumphost:"
	ssh -o 'ControlMaster auto' -o 'ControlPath ~/.ssh/jump.sock' -N -f -L $PORT:$INTGIT:22 root@$JUMPHOST
	echo "Connecting to git in integration:"
	ssh -o 'ControlMaster auto' -o 'ControlPath ~/.ssh/intgit.sock' -o 'UserKnownHostsFile /dev/null' -N -f root@localhost -p $PORT

	# SSH labgit and run rake backup, scp latest backup to host 
	echo "Running gitlab:backup:create"
	ssh -S ~/.ssh/labgit.sock root@$LABGIT gitlab-rake gitlab:backup:create
	echo "Staging backup in /tmp"
	ssh -S ~/.ssh/labgit.sock root@$LABGIT "$(typeset -f); stagelatest"
	echo "Copying over from lab git to localhost"
	scp -o 'ControlPath ~/.ssh/labgit.sock' root@$LABGIT:/tmp/1111111111_gitlab_backup.tar /tmp/
	echo "Copying lab git backup from localhost to integration git server"
	scp -o 'ControlPath ~/.ssh/intgit.sock' -P $PORT /tmp/1111111111_gitlab_backup.tar root@localhost:/var/opt/gitlab/backups
	echo "Would you like to run restore on the integration server now?" 
	read restore 
	if [[ $restore =~ ^y ]]
	then
		echo "Running restore on integration git server"
		ssh -S ~/.ssh/intgit.sock root@localhost -p $PORT BACKUP=1111111111 gitlab-rake gitlab:backup:restore <<< yes
	else
		echo "Not running restore" 
		echo "Backup located at /var/opt/gitlab/backups/1111111111_gitlab_backup.tar"
		echo "-----"
		echo "To backup manually run:"
		echo "BACKUP=1111111111_gitlab_backup.tar gitlab-rake gitlab:backup:restore"
	fi
	cleanup 
else

	echo "VPN Enviro not correct, connected to: $VPNENV" 
	echo "Check VPN connection to d4p4, or start NA Client"
	cleanup 1
fi
{% endcodeblock %}

The final script can be pulled down from [my github account](https://github.com/malnick/scripts/blob/master/connect.sh).

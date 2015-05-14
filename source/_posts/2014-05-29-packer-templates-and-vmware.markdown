---
layout: post
title: "Packer Templates &amp; VMWare"
date: 2014-05-29 12:19:53 -0700
comments: true
categories: 
---
## tl;dr 
There's not a lot of docs on Packer and the logging can be tricky to find sometimes depending on the vm you're booting (which provider backs it). If you're using VMWare and you're booting centos the ```guest_os_type``` key needs to be set appropriatly. 

Some people seem to think this can be $anything that sounds reasonable (I did!) and there is no documentation on what should actually go there (as of writing this, Google was sparce). So if you have a doubt on what the ```guest_os_type``` value should be the best bet is to ```$ diff``` it with an already existing ```*.your_vm_type``` ('vmx', 'ovf', et cetera).

```bash
cat centos65-puppetmaster.json | grep -i guest_os_type
    "guest_os_type": "centos-65",
```

However, if I query an already built `*.vmx` this is incorrect:

```bash
cat master2.vmx | grep -i guestos
   guestos = "redhat"
```

For CentOS at least, your ```guest_os_type``` value should be set to ```redhat```. 

## Back Story

This week I was working with a customer to automate the deployment of some VM's to vSphere. This deployment is replaceing some current scripts and manually configured templates. Actually, a lot of scripts and manually configured templates. 

The long and the short of it, me and my team decided to implement Vagrant and Packer to push out pre-written Packer templates to vSphere via Vagrant's vSphere plugin using the VMWare provider. 

After scripting the json for this node I ran `packer build centos65.json`:

```bash
==> vmware-iso: Downloading or copying ISO
==> vmware-iso: Downloading or copying ISO
vmware-iso: Downloading or copying: http://mirrors.kernel.org/centos/6.5/isos/x86_64/CentOS-6.5
==> vmware-iso: Creating virtual machine disk
==> vmware-iso: Building and writing VMX file
==> vmware-iso: Starting HTTP server on port 8582
==> vmware-iso: Starting virtual machine...
==> vmware-iso: Error starting VM: VMware error:
==> vmware-iso: Deleting output directory...
Build 'vmware-iso' errored: Error starting VM: VMware error:
==> Some builds didn't complete successfully and had errors:
--> vmware-iso: Error starting VM: VMware error:

==> Builds finished but no artifacts were created.
```

The vm booted into fusion and opened but failed in `vmrun`. How did I know that was the issue? 

```bash
grep -r vmrun /var/log/*
system.log:May 29 05:30:32 bohr vmrun[13249]: com.vmware.fusion.78704: Invalid argument
... # lots of other crap 
```

BUT WHAT ARGUMENT???

After digging around I found that logging for this issue was sketchy at best. Syslog, `/var/tmp/vmware`, the `guest_os_type` key needs to have an appropriate value (i.e., arugment from syslog):

```bash
cat centos65-puppetmaster.json | grep -i guest_os_type
    "guest_os_type": "centos-65",
```

However, if I query an already built `*.vmx` this is incorrect:

```bash
cat master2.vmx | grep -i guestos
   guestos = "redhat"
```

After changing the k,v in the json template and running `packer build` the vmrun command ran successfully.

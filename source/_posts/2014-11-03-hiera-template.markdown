---
layout: post
title: "hiera-template"
date: 2014-11-03 05:02:03 -0800
comments: true
categories: 
---
Every time we create a new profile, or update a profile, we have to update our hiera data. This process is error prone and time consuming. Hiera is in an interchange format that can easily be automated, so a tool to write the profiles for us was an obvious decision. 

[hiera-template](https://github.com/malnick/hiera-template) is still in its infancy, and will eventually become a much larger part of our workflow. The main goal of this tool, however, remains the same: automate the generation of our hiera data files from our profile classes. 

hiera-template is up in Rubygems, but be forewarned, it is VERY much still in BETA. Your mileage will vary and your bug reporting is appreciated. 

### Install

```
gem install hiera-template
```

### Usage
hiera-template accepts a single path to a profile as an argument. It can be a local or fully qualified path. 

By default, hiera-template will store all processed yaml's in ```~/.hiera-template/templates/${profile_name}-${hierarchy_level}-template.yaml```

```bash
cd $confdir/modules/profiles/manifests
hiera-template company_frontend.pp
```

The above will create a baseline hiera data file from all the explicit hiera() lookups in the profile. Yes, you read that right, it will not work on non-explicit hiera() lookups. That will be a feature down the road. For now, the following like-lines will be parsed:

```ruby
$myvar = hiera('profiles::company_frontend::myvar'),
```

That line will be written to a yaml file as:

```yaml
profiles::company_frontend::myvar:
```

### Hierarchy Keys
hiera-template uses ```#[keys]``` in the profile to determine what part of the hierarchy the data resides.

Given the following:

```ruby
class profiles::csx_frontend_base(
  #[node]
  $csx_db_name                          = hiera('profiles::csx_frontend_base::csx_db_name'),
  $csx_db_user                          = hiera('profiles::csx_frontend_base::csx_db_user'),
  $csx_db_password_hash                 = hiera('profiles::csx_frontend_base::csx_db_password_hash'),
  #[datacenter]
  $csx_db_host                          = hiera('profiles::csx_frontend_base::csx_db_host'),
  $csx_db_driverclassname               = hiera('profiles::csx_frontend_base::csx_db_driverclassname'),
  $csx_db_url                           = hiera('profiles::csx_frontend_base::csx_db_url'),
  $csx_db_password                      = hiera('profiles::csx_frontend_base::csx_db_password'),
```

hiera-template will create two yaml files in ```~/.hiera-template/templates```:

```
csx_frontend_base-node-template.yaml
csx_frontend_base-datacenter-template.yaml
```

Those templates contain all the keys for the given profile. You can ```cat *-node-template.yaml > my.new.node.yaml``` or ```cat *-datacenter-template.yaml >> out_dc.yaml``` to create or append the keys to data files. Then, all you need to do is fill in your values.

### Upcoming
Since writing in data can be so error prone, and hiera is by it's nature hard to debug, a tool ensures your data written to your data files is the same as what is declared in your profiles - on the flip side, it'll propogate your errors from the profile data declarations to the data file. Either way, you're automating it!

To help write the values to the data files I'll up adding a feature to populate, so you don't have to worry about all that new-fangled white space that YAML loves to hate you for. Populate will prompt your for each value and write it in automatically, so you don't have to open vim: you're prompted with the key, and you type in the value. Done deal. 

### Debugging
Currently, this tool is not hardened by any means. And like everyone else, I can't stay on top of everything. So if you're using it, hit me up with bug reports. There is a ```-D``` option to run at debugger level, and I tried to make it obvious what is going on. That's no substitution for reading ```/lib/template.rb``` if you get a stack trace though. It's a very simple tool, and right now everything lives in ```template.rb``` so it should be easy to figure out.

### Known issues:

1. It will break if you have other comments in the hiera look up declarations other than keys
2. It will not work on implicit lookups, you need hiera() 
3. It'll probably be buggy, but have fun and support it if you find it useful


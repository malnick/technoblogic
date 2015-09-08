---
layout: post
title: "Mantle: Encrypted JSON for the Marathon API"
date: 2015-09-05 13:00:32 -0700
comments: true
categories: 
---
<img style="float: center;" src="https://dl.dropboxusercontent.com/u/77193293/mantle.png">

[Mantle](https://github.com/malnick/mantle.git) is a go utility that wraps the POST process to Mesosphere's Marathon API. Before, users had to store JSON with cleartext environment variables for their Docker container configuration. With Mantle, users can encrypt the values for the "env" parameters passed to Marathon using asynchronous public/private key pairs. Mantle is designed to allow operations or deployment teams to build user-level key pairs, and give those public keys to the users' with the most knowledge of the application's configuration. Those users, can then encode the JSON with Mantle via their public keys and let the deployment team review the JSON and have the final private key to decrypt and deploy to Marathon(s) via Mantle. 

<!-- more -->

### Example Use Case
Create private/public keys and eyaml data from cleartext in JSON for Marathon:

1. ```mantle -generate```: Generates keys for $user defined in config.yaml. User can be overridden with -u. Keys are stored i  n $key_directory specified in config.yaml.

2. ```vi marathon_data.json```:

```json
{
  "container": {
    "type": "DOCKER",
    "docker": {
      "image": "some_repo/some_container_image",
      "network": "BRIDGE",
      "portMappings": [
        { "containerPort": 5050, "hostPort": 0, "protocol": "tcp" }
      ]
    }
  },
  "id": "my-service",
  "env": {
    "MY_LICENSE_KEY": "ENC[my_license_key:12345]",
    "MONGO_PASSWORD": "ENC[qa_mongo_pw:$ecretp@$$word]",
    "JEFFS_SECRET": "ENC[production_secret:13adfafd%^$^$&DFS]",
    "SAFE_DATA": "This is safe"
  },
  "instances": 1,
  "cpus": 0.5,
  "mem": 1024,
  "upgradeStrategy": {
    "minimumHealthCapacity": 0.8,
    "maximumOverCapacity": 0.4
  }
}
```

Add as many ```ENC[eyaml_key:cleartext_value]``` as you need.

3. ```mantle -encode marathon_data.json```: Encodes the cleartext values in each ENC[] statement with the user's public key.

Adds those key/values to the eyaml file, and saves the eyaml file to ```$eyaml_directory/$user.yaml``` as:

```yaml
---
my_license_key: !!binary |
  iFpLHn3wsr6/ZpoolepdT7uhp6hRq/2Tr+LyJXOpJAxkulMsb1pxE8GjKlR9iTTIV9IYnU
  JeIibAaDqfq0SZF8i8xjN6Tx6Ytx3d8BBu2pCT3nDuqpGEDqnZUZDkjp6eRScAtbsPzB8m
  taVfEO9j7zEpU/pWTr9x/awsK8gGp/E=
prod_caleb_secret: !!binary |
  IGpl8fRKGol+XHnCIsha0fTVIsTiq1sdbZ/l0PplAzBdPN+vmjn5Cg7fBeHKoT+7+RCyId
  Yu+7O/gUK1R5zGHJgXA9BV9I3Fh+/dCb3W+c3NFFQNfivHxoad8ggZIX1xk/EyJQAJHTRD
  WypeeyIswps1o5cv1DXj2rJbjBJ33hA=
production_secret: !!binary |
  Sc2D2DlrXf+rsZ6Yovr2/0AE5ZhwfRgKuHax3c3zxDIRvpCcfjqGvbXQUOpE/NwUAu/hNt
  km1vHJ3CgQIwr1Y8SD3WVQ1O2KO87bhcQHmB4HTFsLCtW6m0KsqI5okCSUnsR+yAhKYfqt
  2MBjh38IN3JQz3PbA2psfhrzAg8rt7M=
qa_mongo_pw: !!binary |
  sOOZCr1RsNQT56UZJVxqi39oSC6r5qazGsRncnHP4rdRIAELwW1qME+bBMqhlUh4enqYkM
  vIk6ebR5Oxt+luxAJR5yCfP4Ol7OZjCHIwOCnW5l50ekOuBnJWxhUEQMZe+4DMsK9G+ml0
  /W1mX71ogSK7Kxcn32Ttb2vK9jDfY/k=
user: some_user
```
 new "safe" JSON is saved to ```$safe_dir/marathon_data.json``` as:

```yaml
{
        "container": {
                "docker": {
                        "image": "some_repo/some_container_image",
                        "network": "BRIDGE",
                        "portMappings": [
                                {
                                        "containerPort": 5050,
                                        "hostPort": 0,
                                        "protocol": "tcp"
                                }
                        ]
                },
                "type": "DOCKER"
        },
        "cpus": 0.5,
        "env": {
                "JEFFS_SECRET": "DEC[production_secret]",
                "MONGO_PASSWORD": "DEC[qa_mongo_pw]",
                "MY_LICENSE_KEY": "DEC[my_license_key]",
                "SAFE_DATA": "This is safe"
        },
        "id": "my-service",
        "instances": 1,
        "mem": 1024,
        "upgradeStrategy": {
                "maximumOverCapacity": 0.4,
                "minimumHealthCapacity": 0.8
        }
}
```

4. ```mantle -deploy ~/.mantle/safe/marathon_data.json```: Deploys the "safe" JSON data, first decrypting the DEC[] statement  s, then POSTing that decrypted JSON to each specified Marathon in your config.yaml.

The final POST from our example, with decrypted data:
The final POST from our example, with decrypted data:

```json
{
        "container": {
                "docker": {
                        "image": "some_repo/some_container_image",
                        "network": "BRIDGE",
                        "portMappings": [
                                {
                                        "containerPort": 5050,
                                        "hostPort": 0,
                                        "protocol": "tcp"
                                }
                        ]
                },
                "type": "DOCKER"
        },
        "cpus": 0.5,
        "env": {
                "JEFFS_SECRET": "13adfafd%^$^$\u0026DFS",
                "MONGO_PASSWORD": "$ecretp@$$word",
                "MY_LICENSE_KEY": "12345",
                "SAFE_DATA": "This is safe"
        },
        "id": "my-service",
        "instances": 1,
        "mem": 1024,
        "upgradeStrategy": {
                "maximumOverCapacity": 0.4,
                "minimumHealthCapacity": 0.8
        }
}
```

### Generate key-pairs for Developers
Mantle was developed with the DevOps process in mind. However, it's unlikely that you'll want to give everyone the deployment keys. Mantle allows you to create a key-pair for any user, and give that user only the public key so they can encrypt the JSON. This leaves the ability to deploy in the hands of the deployment or operations team since they have the users' associated private key and can decrypt the JSON. 

1. ```mantle -generate -u sally```: Mantle will generate pub/private keypair and deposit them in `key_dir` specified in config.yaml.

```bash
INFO[0000] Generating PKCS keys...
INFO[0000] Private Key: /Users/malnick/.mantle/keys/privatekey_sally.pem
-----BEGIN RSA PRIVATE KEY-----
MIICXAIBAAKBgQDZ8lDifZdR+xcBZG99t541Vt3WFMOiER/qclIWtjQjtkCt8/ij
dsp/Yn7DHJ3oYB58CbXvXWb9ONMB8Tr1vhCQZVXtJTN2sloUlD7SYne/GrxAJZjT
8vTYoa3ZvvTpWXXYwGiPY8TmnCNqqC0ApqI4o67ZcWIx5FPWgqWu+SHBcQIDAQAB
AoGAB6Rhha+VsMA3LEtTRXs8xu4G1UzhFzu2fMgJbNZyuZXYasEVRNYTf6f6fejw
+Ib2Sq8kfAIwbEyjyXul75v8hKMYBFB8GBxvXuhJuLM1/EWwXtEvHW6p0Km0MZME
eob3kzg4DLe9RxpnCZOYEMhRz9VBbYCcs5G3RcSoXY/2woECQQDvHIhoaln5o7HG
8TZFgZRJ6z/n4H6jfgx08+xKl8llMIwQMGEyftiHmB1ULBxlAM3yYOOxtzHmwj6I
LDkVskSZAkEA6VcXl4g11tk3ZL0fr30+PFvAH6Y3s88aNYr/JNFBb7Edeijs71Mb
Qt8T/2DgpgxYTctQM7mvSh52V9BUNWQSmQJAQBBd/9PWzYrtO8cu6kqAh5mPIrpE
U9uWzNL50TZ/0CvEqyW7NQNFUncQDJhQ90LS6wjImLnjldcfV+65ULXVqQJAFKaI
h/ieCy2eIWQ7caR75YuZLTPgqiEiCKsMeY2rZN8f5LfKgEOynfBwLKG+P/PHvNrJ
dkpwoPahMpRVX4RDwQJBANh7Pp60KVpWrpcCGOPxCCaPAfgY7Hht4BYexBO2HBr1
bjsDYTotBmMx8HExMNf9vQXJkM135kuZ+fevLOcwiV8=
-----END RSA PRIVATE KEY-----

INFO[0000] Public Key: /Users/malnick/.mantle/keys/publickey_sally.pem
-----BEGIN RSA PUBLIC KEY-----
MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDZ8lDifZdR+xcBZG99t541Vt3W
FMOiER/qclIWtjQjtkCt8/ijdsp/Yn7DHJ3oYB58CbXvXWb9ONMB8Tr1vhCQZVXt
JTN2sloUlD7SYne/GrxAJZjT8vTYoa3ZvvTpWXXYwGiPY8TmnCNqqC0ApqI4o67Z
cWIx5FPWgqWu+SHBcQIDAQAB
-----END RSA PUBLIC KEY-----
```

2. Hand out the public key (`~/.mantle/keys/publickey_sally.pem`) to Sally, and keep the private key locally. Ensure Sally places the key in her `key_directory` specified in config.yaml.

3. Have Sally write her JSON with `ENC[$eyaml_key:$cleartext_value]` statements. 

`vi sallys/local/machine/sallys_container.json`:

```json
{
  "container": {
    "type": "DOCKER",
    "docker": {
      "image": "sallys_org/sallys_container",
      "network": "BRIDGE",
      "portMappings": [
        { "containerPort": 5050, "hostPort": 0, "protocol": "tcp" }
      ]
    }
  },
  "id": "my-service",
  "env": {
    "SALLYS_SECRET": "ENC[sallys_qa_secret:superawesomesauce]",
    "MONGO_PASSWORD":"ENC[qa_mongo_password:mongoiswebscale]",
    "NEWRELIC_API_KEY":"ENC[newrelic_api_key:7638263546473822299283737]"
  },
  "instances": 1,
  "cpus": 0.5,
  "mem": 1024,
  "upgradeStrategy": {
    "minimumHealthCapacity": 0.8,
    "maximumOverCapacity": 0.4
  }
}

```

4. ```git clone git@github.com:sallys_org/eyaml sallys/local/machine/sallys_local_eyaml_checkout```: Have Sally pull down the company eyaml directory, and then have her update the `eyaml_dir` in Mantle's config.yaml.

5. ```git clone git@github.com:sallys_org/safe_json sallys/local/machine/sallys_local_safe_checkout```: Have Sally pull down the company safe json directory, and then have her update the `safe_dir` in Mantle's config.yaml.

6. ```mantle -encode sallys/local/machine/sallys_container.json```: Sally can then encode the JSON. Mantle will save the JSON and user-level eyaml in the git repo's she just checked out:

```bash
INFO[0000] Encoding sallys_container.json
WARN[0000] /Users/malnick/.mantle/eyaml/sally.yaml does not exist, creating.
INFO[0000] eyaml saved: /Users/malnick/.mantle/eyaml/sally.yaml
INFO[0000] Safe JSON:
{
        "container": {
                "docker": {
                        "image": "sallys_org/sallys_container",
                        "network": "BRIDGE",
                        "portMappings": [
                                {
                                        "containerPort": 5050,
                                        "hostPort": 0,
                                        "protocol": "tcp"
                                }
                        ]
                },
                "type": "DOCKER"
        },
        "cpus": 0.5,
        "env": {
                "MONGO_PASSWORD": "DEC[qa_mongo_password]",
                "NEWRELIC_API_KEY": "DEC[newrelic_api_key]",
                "SALLYS_SECRET": "DEC[sallys_qa_secret]"
        },
        "id": "my-service",
        "instances": 1,
        "mem": 1024,
        "upgradeStrategy": {
                "maximumOverCapacity": 0.4,
                "minimumHealthCapacity": 0.8
        }
}
INFO[0000] Saving safe JSON for decode: /Users/malnick/.mantle/safe/sallys_container.json
```

Notice the WARN statement. Since Mantle did not find a `eyaml_dir/$user.yaml` it created a new one for her. 

The eyaml looks like this:

```yaml
---
newrelic_api_key: !!binary |
  N4JpKRvQoRBusI7Yp7BN1L/wTdexGH3NFidxvTM0P3IeGM8OnU9TfGI19j+qDQt/XVOQln
  q2h6U/2BlHanQksytxjmuIAX5pVh1IqPFHxp0vkuU8lNffL7Z8VzPEurX4aPEyckQe5Y+E
  OnglwxdWreQnmMuo2Vyu9bhAF+HVWwc=
qa_mongo_password: !!binary |
  UZ1M9L2c/N0AeDlILcP44ACd+niZeaw/BDt1oh78aNf818iTDXAl1c3deUohR12fwEMyCZ
  FHFhErN8u4do97iGeN8QCRdECULj/KOalPG+N70jTxzW9WIpReuPFlCqCrrT+nu/9v2CjO
  1IX5zbxN8UThL9ba2LW25QS1jPEPkMc=
sallys_qa_secret: !!binary |
  UkbR2x+FftMr0O4K13iG/msEDpI8bi7+Mz2NIFxiRmXdwziQtUMYVrvJkpq3hgavGC2DBl
  C0gfmdAa6LfX4zS1lXFHIZD0tpY4dDdqWPFuwRPqVKLLNwiDX46olAEu104iOp6wsRPiJV
  pa92d0uUC4X67BmPF/6LueIVXUTEBYY=
user: sally

```

7. Sally then pushes both eyaml and safe repo's back to git.

8. Now the safe JSON and eyaml repo's can be pulled by the operations team. At this point, a review of the Safe JSON can be made to ensure everything looks right. Finally, we can deploy the safe JSON via Mantle to Marathon with the key for Sally:

```bash
user@localhost: mantle -deploy ~/.mantle/safe/sallys_container.json -u sally

INFO[0000] Deploying ~/.mantle/safe/sallys_container.json
INFO[0000] Decrypted qa_mongo_password to mongoiswebscale
INFO[0000] Decrypted newrelic_api_key to 7638263546473822299283737
INFO[0000] Decrypted sallys_qa_secret to superawesomesauce
INFO[0000] Decoded JSON:
{
        "container": {
                "docker": {
                        "image": "sallys_org/sallys_container",
                        "network": "BRIDGE",
                        "portMappings": [
                                {
                                        "containerPort": 5050,
                                        "hostPort": 0,
                                        "protocol": "tcp"
                                }
                        ]
                },
                "type": "DOCKER"
        },
        "cpus": 0.5,
        "env": {
                "MONGO_PASSWORD": "mongoiswebscale",
                "NEWRELIC_API_KEY": "7638263546473822299283737",
                "SALLYS_SECRET": "superawesomesauce"
        },
        "id": "my-service",
        "instances": 1,
        "mem": 1024,
        "upgradeStrategy": {
                "maximumOverCapacity": 0.4,
                "minimumHealthCapacity": 0.8
        }
}
INFO[0000] POSTing to http://my.marathon1.com
...
```

#### [Check out the git repo here)[https://github.com/malnick/mantle.git]

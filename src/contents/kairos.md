---
author: Clayton Castro
datetime: 2023-01-15:23:35
title: Kairos No Touch Configuration
slug: ""
featured: true
draft: false
tags:
  - kubernetes
  - IAC
  - kairos
ogImage: ""
description:
  Using Kairos to create immutable infrastructure
---

# Immutable Kubernetes with Kairos

## Setup

- dockerfile to build system image
- cloud_config file to configure install
- package the two together as a standalone iso

Two main layers of customization - the base system and the install configuration. 
The base system is customized through a dockerfile that is generally derived from one of the base karios images.
These base kairos images can be anything from minimal alpine systems to full ubuntu releases with niceties like k3s and kubevip already built-in.
Making changes to the provided base systems is as simple as writing a dockerfile. Below is an example of what I'm using in mine.

System customization:
```dockerfile
FROM quay.io/kairos/kairos-ubuntu-22-lts:v2.3.1-k3sv1.27.3-k3s1
RUN apt install -y nfs-common figlet
RUN export VERSION="castro-ubuntu-0.1"
RUN envsubst '${VERSION}' </etc/os-release
```
You can now build this image just as you would any other container. It'll contain everything needed for the os (kernel, init system, etc).
```bash
docker build -t clanktron/kairos-ubuntu-kubevip-k3s .
docker push clanktron/kairos-ubuntu-kubevip-k3s
```

>If you prefer more granular control over your os/container builds, you can follow the instructions in the docs for creating 
karios compatible images ["from scratch"](https://kairos.io/docs/reference/build-from-scratch/). Taking this lower level 
approach doesn't add a monumental amount of complexity and might provide the flexibility your particular organization needs.

Now comes writing the installation config. The syntax is extremely similar to cloud-init and supports even more options.
In this example we'll be enabling HA deployment of k3s with a kubevip ip. 
Cluster configuration/setup can be done on a per cloud_config basis [(as seen here in their docs)](https://kairos.io/docs/examples/multi-node), or it can be
completely automated using kairos' experimental p2p network support. This allows us to use a single iso for all the nodes, letting the p2p network
do all the coordination of node joining in the background. The p2p functionality karios has integrated has quite the multitude of applications.
That being said, in this example we're just using the p2p network for the cluster bootstrapping and future node additions, not actual cluster communication during operation.

P2P token generation:
```bash
docker run -ti --rm quay.io/mudler/edgevpn -b -g
# output should be similar to below
b3RwOgogIGRodDoKICAgIGludGVydmFsOiA5MDAwCiAgICBrZXk6IGtkdGtoY21sMHVJM2hzVUFUMXpUY1B2aDhBblkzNDZUbHJ3NklVRmUxYUoKICAgIGxlbmd0aDogNDMKICBjcnlwdG86CiAgICBpbnRlcnZhbDogOTAwMAogICAga2V5OiBIcEJGaGxxdlFrcTZVd3BPSTBPVkJWQ1daRjNRYlE3WGdDa1R1bnI0cGV3CiAgICBsZW5ndGg6IDQzCnJvb206IGFBUE5oRTdlODgyZUZhM2NMTW56VkM0ZDZjWFdpTU5EYlhXMDE4Skl2Q3oKcmVuZGV6dm91czogOHVzaGhzNnFrTU92U2ZvQmZXMHZPaEY1ZFlodVZlN1Flc00zRWlMM2pNMwptZG5zOiBJZ0ljaGlvRlVYOFN6V1VKQjNXQ0NyT2UzZXZ3YzE4MWVIWm42SmlYZjloCm1heF9tZXNzYWdlX3NpemU6IDIwOTcxNTIwCg==
```
The full spec for the supported cloud config syntax can be found [here](https://kairos.io/docs/reference/configuration).

Installation configuration (cloud_config.yaml):
```yaml
#cloud-config
hostname: kairoslab-{{ trunc 4 .MachineID }}
users:
- name: kairos
  ssh_authorized_keys:
  # Replace with your github user and un-comment the line below:
  - "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDOTdQLlqHFSdRU4iYNTx4Dgl+BUKnmSeV1od4BCvot0 clayton@ClaytonsMacBookPro.socal.rr.com"
  # - github:clanktron

kubevip:
  eip: "192.168.1.110"

p2p:
 # Disabling DHT makes co-ordination to discover nodes only in the local network
 disable_dht: true #Enabled by default

 vpn:
   create: false # defaults to true
   use: false # defaults to true
 # network_token is the shared secret used by the nodes to co-ordinate with p2p.
 # Setting a network token implies auto.enable = true.
 # To disable, just set auto.enable = false
 network_token: "b3RwOgogIGRodDoKICAgIGludGVydmFsOiA5MDAwCiAgICBrZXk6IGtkdGtoY21sMHVJM2hzVUFUMXpUY1B2aDhBblkzNDZUbHJ3NklVRmUxYUoKICAgIGxlbmd0aDogNDMKICBjcnlwdG86CiAgICBpbnRlcnZhbDogOTAwMAogICAga2V5OiBIcEJGaGxxdlFrcTZVd3BPSTBPVkJWQ1daRjNRYlE3WGdDa1R1bnI0cGV3CiAgICBsZW5ndGg6IDQzCnJvb206IGFBUE5oRTdlODgyZUZhM2NMTW56VkM0ZDZjWFdpTU5EYlhXMDE4Skl2Q3oKcmVuZGV6dm91czogOHVzaGhzNnFrTU92U2ZvQmZXMHZPaEY1ZFlodVZlN1Flc00zRWlMM2pNMwptZG5zOiBJZ0ljaGlvRlVYOFN6V1VKQjNXQ0NyT2UzZXZ3YzE4MWVIWm42SmlYZjloCm1heF9tZXNzYWdlX3NpemU6IDIwOTcxNTIwCg=="

 # Automatic cluster deployment configuration
 auto:
   # Enables Automatic node configuration (self-coordination)
   # for role assignment
   enable: true
   # HA enables automatic HA roles assignment.
   # A master cluster init is always required,
   # Any additional master_node is configured as part of the 
   # HA control plane.
   # If auto is disabled, HA has no effect.
   ha:
     # Enables HA control-plane
     enable: true
     # Number of HA additional master nodes.
     # A master node is always required for creating the cluster and is implied.
     # The setting below adds 2 additional master nodes, for a total of 3.
     master_nodes: 2

install:
  # selects biggest drive
  device: "auto"
  reboot: true
  poweroff: false
  auto: true # Required, for automated installations
```

## Network Install

Usually booting from the network consists of PXE to iPXE chaining (or just flashed iPXE).
Instead of this traditional method I'm going to be trying out karios' custom bootstrapping tool [AuroraBoot](https://kairos.io/docs/reference/auroraboot).
Rather than going through all the trouble of setting up a TFTP server, HTTP server, and configuring my existing DHCP server, 
I can run a simple docker image and have everything set up in seconds.

```bash
# make sure to mount your cloud_config file inside the container
docker run -v "$PWD"/config.yaml:/config.yaml \
                    --rm -ti --net host quay.io/kairos/auroraboot \
                    --set "container_image=docker.io/clanktron/kairos-ubuntu-kubevip-k3s" \
                    --cloud-config /config.yaml
```
Once that container has started, any machine configured to boot from the network will automatically have our image installed to it.

## ISO Creation

If a prebuilt iso is more suitable for your needs then that's an option as well. 
To create the ISO for installation you can either use AuroraBoot again or do a more manual build and use the kairos `osbuilder-tools` image. 

AuroraBoot:
```bash
IMAGE=clanktron/kairos-ubuntu-kubevip-k3s
docker pull $IMAGE
# Build the ISO
docker run -v $PWD/cloud_init.yaml:/cloud_init.yaml \
                    -v $PWD/build:/tmp/auroraboot \
                    -v /var/run/docker.sock:/var/run/docker.sock \
                    --rm -ti quay.io/kairos/auroraboot \
                    --set container_image=docker://$IMAGE \
                    --set "disable_http_server=true" \
                    --set "disable_netboot=true" \
                    --cloud-config /cloud_init.yaml \
                    --set "state_dir=/tmp/auroraboot"
# Artifacts are under build/
sudo ls -liah build/iso
total 778M
34648528 drwx------ 2 root root 4.0K Feb  8 16:39 .
34648526 drwxr-xr-x 5 root root 4.0K Feb  8 16:38 ..
34648529 -rw-r--r-- 1 root root  253 Feb  8 16:38 config.yaml
34649370 -rw-r--r-- 1 root root 389M Feb  8 16:38 kairos.iso
34649371 -rw-r--r-- 1 root root   76 Feb  8 16:39 kairos.iso.sha256
```

"Manual":
```bash
# You can replace this step with your own grub config. This GRUB configuration is the boot menu of the ISO
mkdir -p files-iso/boot/grub2
curl -LO files-iso/boot/grub2/grub.cfg https://raw.githubusercontent.com/kairos-io/kairos/master/overlay/files-iso/boot/grub2/grub.cfg
# Copy your config file
cp -v cloud_config.yaml files-iso/cloud_config.yaml
# Specify your custom kairos image
export IMAGE_NAME=kairos-ubuntu-kubevip-k3s
export IMAGE=clanktron/$IMAGE_NAME
docker run -v $PWD:/cOS \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -i --rm quay.io/kairos/osbuilder-tools:latest \
    --name "$IMAGE_NAME" \
    --debug build-iso \
    --date=false --local \
    --overlay-iso /cOS/files-iso $IMAGE \
    --output /cOS/
```
We can now use this iso as an automated installer for our custom immutable operating system. 

### Other info

For more modularity within an organization, creating a secondary ISO with an embedded cloud-config could be desireable. 
The most likely use case for this is larger organizations that might want separate isos' for config and base systems (rather than 
baking in the cloud_config like in the above example).

Process for creating said secondary ISO:
```bash
# setup build dir
mkdir -p build
cd build
# create necessary files to be embedded in the iso
touch meta-data
cp -rfv cloud_init.yaml user-data
# build the supplementary iso
export ISO_NAME=custom-ubuntu
mkisofs -output $ISO_NAME.iso -volid cidata -joliet -rock user-data meta-data
```

## General Takeaways

limitations:
- can't netboot or create custom iso on mac or windows
    - you can create an iso from the prebuilt images but to use your custom image you need access to the docker socket (at least when I tried)

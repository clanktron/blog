---
author: Clayton Castro
datetime: 2023-01-15:23:35
title: Using Elemental to Streamline Self Managed Kubernetes Deployments
slug: ""
featured: true
draft: false
tags:
  - kubernetes
  - IAC
ogImage: ""
description:
  A breakdown of Rancher Elemental and configuring your OS with IAC.
---

## Introduction

Deploying kubernetes to virtualized or bare metal systems can often pose a challenge to new teams or 
organizations. Traditionally the process is rather tedious and involves a great deal of work from a 
dedicated infrastructure team. Their primary tasks can roughly be broken down into two main categories:

* Maitenance of the underlying OS (ensuring necessary dependencies are installed, security considerations, etc)
* Automation of the cluster tasks themselves (deployment, upgrades, etc)

As k8s has grown in popularity a number of tools have emerged to help expedite these tasks. Common 
examples of such are custom ansible scripts, terraform modules, or even standalone binaries like the 
famous [k3sup](https://github.com/alexellis/k3sup). While these tools are perfectly capable in their own
right, they each have their own shortcoming when it comes to managing the entire lifecycle of a 
cluster. Ansible in junction with something like k3sup is probably the closest thing
we have now to an end to end solution, though this can often come with significant management overhead and nodes can 
suffer from configuration drift if they are manually tampered with.

## Enter Elemental

Rancher has been hard at work to remedy this gap in tooling and has recently come up with a solution called
"Elemental". The official website descibes it as "a software stack enabling a centralized, full 
cloud-native OS management with Kubernetes". From a bird's eye view Elemental's architecture can be
broken down into two pieces: the [Elemental toolkit](https://rancher.github.io/elemental-toolkit/docs/)
and [Rancher Elemental](https://elemental.docs.rancher.com/).

I'll first give a brief introduction of these pieces from a technical standpoint and then provide a demo on how they 
can be used to create a k3s cluster faster than any current solution to date.

>Note: While Rancher Elemental exclusively integrates with clusters managed by
Rancher, elemental-toolkit is simply used to configure the OS and can be used regardless of whether you're using Rancher 
or not. If you're looking to take advantage of elemental-toolkit for k8s deployment/management without the Rancher integration
I'd recommend looking into the [Kairos](https://kairos.io/) project. 

## Elemental-toolkit

The elemental toolkit takes a brand new approach to OS maitenance by allowing container images to be 
bootable as full blown operating systems. These resulting OS's are immutable linux derivatives and can be
used for anything from typical cloud VM's to even something as small as an embedded device. It's also 
important to note that resulting container OS does not use a container runtime (containerd, docker, etc) 
and as such does not add any compute or management overhead. A major benefit of this 
approach is the ability to incorporate IAC (infrastructure as code) practices into OS lifecycle management. The 
toolkit uses yaml files with a custom cloud-init style syntax to specify exactly how you want your OS built. 
This could include what dependencies you want included, the name of the disk you want your OS installed on,
custom grub or network configuration, and anything else you could possibly want to configure. If you're 
looking for the full technical details on how this is achieved refer to the toolkit link in the 
above introduction.

## Rancher Elemental

If you're looking to take advantage of this tech without building a custom ISO, the rancher team has created a pre-built solution called 
"Elemental Teal". This ISO is built on SLE-Micro and will automatically create slim k3s/rke2 nodes that can be managed entirely
from your rancher console. 

## Putting it all Together

Now we get to the fun part: spinning up the immutable cluster.

In order to complete this demo you'll need a few things:

* A Rancher server (2.7.0) configured (server-url set)
* A machine (bare metal or virtualized) with TPM 2.0 and UEFI
* Helm Package Manager 
* Docker or Rancher Desktop or Podman

Now that you have these available let's install the elemental operator on your rancher cluster. This will create the necessary crds for operation and you should now see a OS management panel
on your rancher dashboard.

```
$ helm upgrade --create-namespace -n cattle-elemental-system --install elemental-operator oci://registry.opensuse.org/isv/rancher/elemental/stable/charts/rancher/elemental-operator-chart
```

Once that's finished we can apply the following sample manifests to specify how we'd like to register our newly created nodes with the management cluster. For more information on 
how these can be used to make node pools refer to the [architecture explanation in the Elemental docs](https://elemental.docs.rancher.com/architecture).

>Note: This next step assumes that your node(s) will have a /dev/sda disk available for the OS to be installed on. 
If your node doesnt have that disk you'll need to manually edit the registration.yaml file before applying so that it matches the proper disk name.

```
$ kubectl apply -f https://raw.githubusercontent.com/rancher/elemental-docs/main/examples/quickstart/selector.yaml
$ kubectl apply -f https://raw.githubusercontent.com/rancher/elemental-docs/main/examples/quickstart/cluster.yaml
$ kubectl apply -f https://raw.githubusercontent.com/rancher/elemental-docs/main/examples/quickstart/registration.yaml
```
Now we can get the registrationURL from rancher and inject it into our ISO so our node(s) know where to connect to for management.

```
$ wget --no-check-certificate `kubectl get machineregistration -n fleet-default my-nodes -o jsonpath="{.status.registrationURL}"` -O initial-registration.yaml
$ wget -q https://raw.githubusercontent.com/rancher/elemental/main/.github/elemental-iso-add-registration && chmod +x elemental-iso-add-registration
# If you're using Rancher Desktop you'll need to edit this script to use nerdctl in lieu of docker or podman
$ ./elemental-iso-add-registration initial-registration.yaml
```

Our ISO is now ready for deployment and can be used to boot any number of nodes you'd like. Under the hood it'll do the following:

* Register with the registrationURL given and create a per-machine MachineInventory
* Install Elemental Teal to the given device
* Reboot

Once the nodes are ready we simply need to add a label to our machineinventory so the nodes can be selected for cluster bootstrapping. This can be achieved with the following:

```
$ kubectl -n fleet-default label machineinventory $(kubectl get machineinventory -n fleet-default --no-headers -o custom-columns=":metadata.name") location=europe
```

Now all we need to do is wait! After a few minutes the cluster should be up and running and you'll be able be able to manage it entirely from your rancher dashboard.
Or if you're like me you'll download the respective kubeconfig from rancher and manage it in k9s from the terminal.

Though I won't be convering how to do so here you can also manage your node OS's entirely from your rancher console even after the cluster is provisioned. Instructions
on how to upgrade your nodes to your desired configuration can be found [in the docs](https://elemental.docs.rancher.com/upgrade).

If you had any issues with the demo a more detailed explanation can be found [here](https://elemental.docs.rancher.com/quickstart).

Happy clustering!

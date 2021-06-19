
# boonkeato/openshift-squid:1.0

- [Introduction](#introduction)
- [Getting started](#getting-started)
  - [Installation](#installation)
  - [Quickstart](#quickstart)
  - [Command-line arguments](#command-line-arguments)
  - [Configuration](#configuration)
  - [Usage](#usage)
  - [Logs](#logs)
- [Troubleshooting in Docker](#troubleshooting-in-docker)
  - [Shell Access](#shell-access)
- [Openshift](#openshift)
  - [ConfigMap](#configmap)
  - [Deployment Config](#deployment-config)
  - [Service](#service)
  - [How to add proxy server to your Java application on Openshift](#how-to-add-proxy-server-to-your-java-application-on-openshift)

# Introduction

This project is modified from the popular [sameersbn/docker-squid](https://github.com/sameersbn/docker-squid) repo. While using the repo as is for my POC i faced issues with Openshift's Security Context Contraints (SCC) on my cluster which forces the POD to run into crashloop. This roadblock prompted me to modify the `Dockerfile` as well as the `squid.conf` to make it non-root user friendly. 

Squid is a caching proxy for the Web supporting HTTP, HTTPS, FTP, and more. It reduces bandwidth and improves response times by caching and reusing frequently-requested web pages. Squid has extensive access controls and makes a great server accelerator.

# Getting started

## Installation

Unfortunately this docker image is not published in any docker registry. You will need to build the image yourself.

```bash
docker build -t boonkeato/openshift-squid:1.0 .
```

## Quickstart

Start Squid locally easily using [Docker Compose](https://docs.docker.com/compose/):

```bash
docker-compose up
```

*Reference template: [docker-compose.yml](docker-compose.yml)*

## Command-line arguments

You can customize the launch command of the Squid server by specifying arguments to `squid` on the `docker run` command. For example the following command prints the help menu of `squid` command:

```bash
docker run --name openshift-squid -it --rm \
  --publish 3128:3128 \
  --volume compose-conf:/etc/squid \
  boonkeato/openshift-squid:1.0 -h
```
*If you are using the [docker-compose.yml](docker-compose.yml), it mounts the compose-conf folder to etc/squid automatically*

## Configuration

Squid is a full featured caching proxy server and a large number of configuration parameters. To configure Squid as per your requirements mount your custom configuration at `/etc/squid/squid.conf`.

```bash
docker run --name squid -d --restart=always \
  --publish 3128:3128 \
  --volume /path/to/squid.conf:/etc/squid/squid.conf \
  boonkeato/openshift-squid:1.0
```

Alternatively, if you are using [docker-compose.yml](docker-compose.yml), the you can make the configuration changes in `squid.conf` which is located in the `compose-conf` folder


## Usage

Configure your web browser network/connection settings to use the proxy server which is available at `172.17.0.1:3128`

To use Squid in your Docker containers add the following line to your `Dockerfile`.

```dockerfile
ENV http_proxy=http://172.17.0.1:3128 \
    https_proxy=http://172.17.0.1:3128 \
    ftp_proxy=http://172.17.0.1:3128
```

For Java applications, and if you are using Apache HTTPClient and ServiceWrapper's RestService, you can proxy your outbound connection through squid by introducing the following JAVA_OPTS

```java
-Dhttp.proxyhost=<squid proxy ip>
-Dhttp.proxyport=3128
-Dhttps.proxyhost=<squid proxy ip>
-Dhttps.proxyport=3128 
```

# Troubleshooting in Docker

## Shell Access

For debugging and maintenance purposes you may want access the containers shell. There are 2 ways of invoking a shell for troubleshooting:

### via Docker Compose
```bash
docker-compose run squid bash
```

### via Docker run
```bash
docker run --rm -it 407 bash
```
Where `407` is the first 3 characters of image id

# Openshift
boonkeato/openshift-squid docker image supports running on openshift as a non-root user. Please note that you will need to publish the docker image to appcanvas' docker registry in order for this to work.


## ConfigMap
```yml
apiVersion: v1
kind: ConfigMap
metadata:
  name: proxy-configmap
data:
  squid.conf: |-
    http_port 3128

    acl SSL_ports port 443
    acl CONNECT method CONNECT

    http_access deny CONNECT !SSL_ports
    http_access allow localhost manager
    http_access deny manager
    http_access allow all

    coredump_dir /var/spool/squid
    pid_filename /var/run/squid/squid.pid
```
*Reference: [configmap.yml](./platform/templates/configmap.yml)*

* Mounts the squid.conf into the `/etc/squid` folder within the container
* If the https server you are connecting to does not run on port 443, you will need to include the port (8088 in the case below) in the configmap above as such:
  * `acl SSL_ports port 443 8088`
* Important to note about pid_filename
  * /var/run is owned by root user and by default Squid will create squid.pid in this folder.
  * Since pods on openshift will not execute with root user, we need to change the pid_filename location to a directory we can write to. Otherwise we got permission error: `/var/run/squid.pid: (13) Permission denied`

## Deployment Config
```yml
apiVersion: apps.openshift.io/v1
kind: DeploymentConfig
metadata:
  name: squid
spec:
  replicas: 1
  selector:
    app: squid
  template:
    metadata:
      labels:
        app: squid
    spec:
      volumes:
        - name: proxy-config
          configMap:
            name: proxy-configmap
        - name: data
          emptyDir: {}
      containers:
        - name: squid
          image: boonkeato/openshift-squid:1.0
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: 3128
              protocol: TCP
          volumeMounts:
            - name: proxy-config
              mountPath: /etc/squid
            - name: data
              mountPath: /var/spool/squid
```
*Reference: [deploymentconfig.yml](./platform/templates/deploymentconfig.yml)*

* In the example above, the image url is pointing at the `boonkeato/openshift-squid:1.0`. Update this accordingly

## Service
```yml
apiVersion: v1
kind: Service
metadata:
  name: squid-proxy-svc
spec:
  ports:
    - port: 3128
      protocol: TCP
      targetPort: 3128
  selector:
    app: squid
```
*Reference: [service.yml](./platform/templates/service.yml)*

## How to add proxy server to your Java application on Openshift

Assuming you are exposing JAVA_OPTS environment variable in your application, you can add proxy server settings by introducing the following system properties in JAVA_OPTS environment variable:
* `-Dhttp.proxyhost=squid-proxy-svc -Dhttp.proxyport=3128`
* `-Dhttps.proxyhost=squid-proxy-svc -Dhttps.proxyport=3128`

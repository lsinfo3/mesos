# How to provision our very own mesos cluster

 1. Place `public_haproxy.pem`, `zeus_informatik_uni-wuerzburg_de.crt` and `ls3-validator.pem` in this folder. (Obtain the latter from Steffen, the first two should become not needed anymore as soon as the new gatewayos branch gets merged)
 2. Source your OpenStack RC file
 3. Run `TF_VAR_os_user=christian.schwartz terraform apply`, obviously replacing christian.schwartz with your LS3 LDAP username and enter your password (in plaintext. I know.)
 4. Wait
 5. Run `knife ssh 'name:mesos-*' -a cloud.public_ipv4 'sudo chef-client'`, (or wait for the nodes to check in on their own), this will make sure that each node knows the proper ZK url

You should now have a working mesos cluster. Until we get a working DNS in OpenStack, you will need to adapt your `/etc/hosts` file to contain references to mesos-master-1 and host-mesos-slave-{1..n} (n being currently 5).
Then, you can visit mesos-master-1.informatik.uni-wuerzburg.de:5050 to find the mesos web interface.
You will probably also want to provision a marathon node, this is currently not included in the terraform file (but it really should), so you have to run `knife openstack server create -N marathon -f2 -I ubuntu14.04-x64 --openstack-ssh-key-id terraform --no-host-key-verify --ssh-user ubuntu --bootstrap-network public -a -r 'recipe[host-marathon]' --hint openstack --yes`
Make sure to also add the floating IP of marathon to your `/etc/hosts` file.
Than, you can visit `marathon.informatik.uni-wuerzburg.de:8080` to schedule your jobs.

# How to build mesos locally

You need this, if you want to connect to mesos directly, because you

 a. Want to build stuff
 b. Want to run an executor locally, for example using spark.

Examples are for OSX, but adaptable of course (assuming you are using homebrew, which you should).

1. Install dependencies `brew install wget git autoconf automake libtool subversion maven apr`
2. Download the mesos version we are using (currently 0.27) `wget http://www.apache.org/dist/mesos/0.27.1/mesos-0.27.0.tar.gz`
3. Extract it somewhere `tar -zxf mesos-0.27.1.tar.gz` (we will call the resulting directory MESOS_HOME)
4. `cd` into MESOS_HOME
5. run `./bootstrap`
6. `mkdir build && cd build`
7. `../configure --with-apr=/usr/local/Cellar/apr/1.5.2/libexec && make` (the --with-libapr line may obviously change)`


# How to use our very own mesos cluster

## Spark

Have a spark.tgz (I'm recommending spark-1.6.0-bin-hadoop2.6.tgz, rename as required) ready to be served from each of the mesos-slaves via http (this should really work via openstack object storage, as soon as the proxy is running), if it is not yet running, serve one yourself via `python -m SimpleHTTPServer` in a directory where your spark.tgz us located. 

`MESOS_NATIVE_JAVA_LIBRARY=$MESOS_HOME/build/src/.libs/libmesos.dylib SPARK_EXECUTOR_URI=http://WHERE_YOU_PLACED_SPARK/spark-1.6.0.tgz ./bin/spark-shell --master mesos://mesos-master-1.informatik.uni-wuerzburg.de:5050`
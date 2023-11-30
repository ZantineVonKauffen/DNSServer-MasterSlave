# DNSServer-MasterSlave  
The following content of this file is a description of the architecture, installation and decisionmaking for the creation of a homebrew DNS Server configuration. This DNS configuration was made using BIND9 DNS service, utilizing two virtual machines made and hosted with Vagrant Box virtualization services. Inside this repository's folder are:  
  - A VagrantFile configuration file written in `ruby` with the initial configuration for both machines on startup
  - A provision.sh linux bash script that contains commands for both virtual machines to execute on startup
  - Two folders called *Master* and *Slave* which contain the configuration files for BIND9 to build the DNS server and get it working  
  - A folder with two scripts to test the configuration of the DNS server, one written in `bash` and the other written as `batch`

## Architecture  
The virtual machines were created using Vagrant virtualization service, which runs on the console command of either Windows or Linux. To create vagrant boxes, a directory must be chosen to then issue the command `vagrant init`, which will create a VagrantFile that is written in `ruby` which is meant to be edited to add initial configuration and properties to the machine that will be created. For this activity, the VagrantFile was configured to create virtual machines with *debian11/bullseye* operating system, 4 GB of RAM memory and without a base clone (my own choice, which then I regretted a little bit).  
The VagrantFile is the following:  

        Vagrant.configure("2") do |config|  
      config.vm.box = "debian/bullseye64"  
      config.vm.provider "virtualbox" do |vb|  
          vb.memory = "4096" #RAM  
          vb.linked_clone =  false  
      end # provider  
      config.vm.define "tierra" do |tierra|  
          tierra.vm.hostname = "tierra.sistema.sol"  
          tierra.vm.network :private_network, ip: "192.168.57.103"  
          tierra.vm.provision "shell", path: "provision.sh"  
      end  
      config.vm.define "venus" do |venus|  
         venus.vm.hostname = "venus.sistema.sol"  
         venus.vm.network :private_network, ip: "192.168.57.102"  
         venus.vm.provision "shell", path: "provision.sh"  
      end  

With this code, I defined the base characteristics of the virtual machines I want to create, using virtualbox as virtualization provider. There are two virtual machines: *tierra* and *venus*, which are the two Name-servers of the DNS configuration. Tierra is the Master of the configuration, while Venus is the Slave.    
Both machines are created as equals, the only differences being their hostname and their IP address. Both computers excecute a `provision.sh` linux script that contains some commands to download BIND9 packages once both are installed and running, this way saving time in the process of the configuration. With this VagrantFile in the initialized folder, using the command `vagrant up` will create both virtual machines inside the folder and instantly boot them. These computers are created very rapidly due to them being pre-installed, so no installation process is required during their startup, they only need to be downloaded. Both computers can be used by connecting to them via SSH using the command `vagrant ssh tierra | venus`.  

Now that I have explained the VagrantFile usage, it is now time to explain the structure of this DNS configuration  
The FQDN used for this practice is *sistema.sol*, there are four devices in this domain, two Name Servers, one Mail Server and one Host, each with their respective IP addresses.  
To configure this DNS server, an intranet was used, which linked devices *tierra* and *venus*, using the IP network address 192.168.57.0/24

Device | FQDN | IP
--- | --- | ---
Host device (Linux with GUI) | mercurio.sistema.sol | 192.168.57.101
CLI Debian VM (Slave NS) | venus.sistema.sol | 192.168.57.102
CLI Debian VM (Master NS) | tierra.sistema.sol | 192.168.57.103
Windows Mail Server | mercurio.sistema.sol | 192.168.57.104

This sums it all up for the architecture of the DNS server. Taking this in mind, I proceed to configure the BIND9 service in both *tierra* and *venus*

## The Activity

The activity of this project consists on the following
  - Stablish option to *dnssec-validation* **yes**
  - Configure Venus and Tierra to be the default domain name servers in `/etc/resolv.conf`
  - The Domain Name Server's name will be *sistema.sol*
  - Servers will allow recursivity for devices in the networks 127.0.0.0/8 and 192.168.57.0/24
  - The Master server will be Tierra, with authority over the direct and reverse zones
  - The Slave server will be Venus, whose master is Tierra
  - TTL in cache for Negative answrs will be of 2 hours (7200 seconds)
  - All queries for which the server is not authorized to answer will be redirected to 208.67.222.222
  - Tierra will have alias *ns1.sistema.sol* and Venus will have alias *ns2.sistema.sol*
  - *mail.sistema.sol* will be Marte's alias
  - Device *marte.sistema.sol* will be the domain server's mail exchange server

## Instalation

The installation process is very smooth, given that Vagrant installs and boots up both computers automatically.  
As said before, the provision file that was configured for both VMs was dedicated to execute some commands. These commands were:  

    sudo apt -y update
    DEBIAN_FRONTEND=noninteractive sudo apt -y upgrade
    sudo apt -y install bind9
    
    cp /vagrant/named.conf.options /etc/bind
    
    sudo systemctl restart bind9

With this script, by the time a connection is made to any of the computers, they will already have BIND9 installed, saving precious time.  
The installation process can actually be understood as the "configuration" process, since both computers have to be parametered to run the DNS correctly.  
The first step towards a proper configuration is to check both computers' hostnames are correct. This is done by opening the file `etc/hosts` and checking its contents look like the following:  
For *tierra*

    127.0.0.1 localhost
    127.0.1.1 tierra.sistema.sol sistema.sol

For *venus*

    127.0.0.1 localhost
    127.0.1.1 venus.sistema.sol sistema.sol

Having both computers' hostnames be like this ensure both recognize themselves as such, and will know when they are being referred to in the case a request comes by in the network.  

Next step is to configure `/etc/resolv.conf` to tell both computers which servers are their default domain-name servers. In this case we want both to solve addresses using themselves (since they are the nameservers) and working in the domain *sistema.sol*  
All computers that are part of this architecture / configuration should have their `/etc/resolv.conf` file like this:  

    domain sistema.sol
    search sistema.sol
    nameserver 192.168.57.103
    nameserver 192.168.57.102

Note the two *nameserver* parameters there: they mean *tierra* and *venus*, respectively, and they are the ones that will resolve all names in the configuration.

Finally, the last step before ***actually** configuring the server, is to tell BIND9 to only use the IPv4 protocol, since not a single IPv6 address was used during the entire activity.  
This is done by editing the file `etc/default/named` adding a single `-4` at the end of the last line of the file, so the file looks like this:  

    #
    # run resolvconf?
    RESOLVCONF=no

    #startup options for the server
    OPTIONS="-u bind -4"

After having these files handled, the **real** work begins.  
To configure BIND, the files inside `/etc/bind/` are editted. There is a .php file called `/etc/bind/named.conf` in that directory, which is the main configuration file, which makes calls with *include* to another three files that contain the actual options to configure the entire server, therefore, this file is not the one that will be used, but rather, two of those three will be modified.  
The files that are needed for this activity are `/etc/bind/named.conf.options` and `/etc/bind/named.conf.local`.  
`/etc/bind/named.conf.options` contains the global configuration for the server  
`/etc/bind/named.conf.local`, on the other side, contains the local configuration for zones and reverse zones that need to be specified  

The first step is to configure `/etc/bind/named.conf.options` for both machines, so let's begin with *tierra*  
`/etc/bind/named.conf.options`  

    #this acl is a unit that stores the trusted IP addresses for recursion, simplifying writting later on
    acl trusty {
    	192.168.57.0/24;
    	192.168.57.102;
    	192.168.57.103;
    	127.0.0.0/8;
    };
    options {
    	directory "/var/cache/bind";

      #The forwarders are the DNS servers to which packets that can't be processed by this DNS server configuration are sent to be processed instead
    	 forwarders {
    		208.67.222.222;
    	};
     #By allowing transfer to IP 192.168.57.102 the local configuration is transfered to Venus, which is the Slave DNS and depends on Tierra's configuration, specifically the zone configuration, which Venus requires from Tierra
    	allow-transfer { 192.168.57.102; };
    	listen-on port 53 { 192.168.57.103; }; # Requests will be heard on port 53, which is the entry port for UDP packets, UDP being the main protocol used to comunicate with DNS servers. Inside {} goes the IP address of tierra's listening interface
    	recursion yes; # #Allows recursive queries
    	allow-recursion { trusty; }; # Allows recursion on the IP addresses contained by trusty, the acl defined in the beggining of the file
    	//========================================================================
    	// If BIND logs error messages about the root key being expired,
    	// you will need to update your keys.  See https://www.isc.org/bind-keys
    	//========================================================================
    	dnssec-validation yes; #Allows security via validation of answers from DNS servers to clients to avoid DNS spoofing
    
    #	listen-on-v6 { any; }; #This line is commented because this configuration does not use IPv6.
    };

Now, the same is done in *venus'* configuration file  
`/etc/bind/named/conf.options` 

        acl trusty {
    	192.168.57.0/24;
    	127.0.0.0/8;
    	192.168.57.103;
    	192.168.57.102;
    };
    options {
    	directory "/var/cache/bind";    
    	forwarders {
    		208.67.222.222; #uses the same forwarder configuration
    	};
    	listen-on port 53 { 192.168.57.102; }; # Same as before, but now the IP address is the one for venus' listening port, still using UDP protocol
    	recursion yes;
    	allow-recursion { trusty; }; #same as before
    	//========================================================================
    	// If BIND logs error messages about the root key being expired,
    	// you will need to update your keys.  See https://www.isc.org/bind-keys
    	//========================================================================
    	dnssec-validation yes; #still requires validation
    
    #	listen-on-v6 { any; };
    };

After editing these files and saving changes, it is time to move on to edit the file `/etc/bind/named.conf.local` in both computers, so let's begin again with *tierra*  
Remember, Tierra is the master of this configuration, so the files will be slightly different from each other
`/etc/bind/named.conf.local` 

    #This is the zone to be defined, taking into account the name of the domain.
    zone "sistema.sol" {
            type master; #Tierra is the master of this configuration, and has to be declared as such
            file "/var/lib/bind/sistema.sol.dns"; #This file contains the zone's Registry Resources, which contains all the data clients require for address resolvs
            allow-transfer { 192.168.57.102; }; #This is already present in the big configuration file from before, but can also be written here. This line means that all the registry resources data will be transfered to the slave
    };

    #This is the reverse zone for reverser resolv. It allows resolving using IP addresses instead of domain names. The first bit is the third bit of the IP address of the network, followed by 168.192.in-addr.arpa
    zone "57.168.192.in-addr.arpa" { 
            type master;
            file "/var/lib/bind/sistema.sol.rev"; #Contains the registry resources
            allow-transfer { 192.168.57.102; }; #again, transfers all the configuration to the salve, Venus
    };

As it can be seen, the Master-Slave relationship between Tierra and Venus is making itself more visible now. But, what does it mean that the *transfer* is allowed between Tierra and Venus? It means that Venus does not have its own resource registry files, but rather, uses tierra's, which are transfered to Venus. Venus does have its own files to hold this information, though, because if it was not stored somewhere, it would make no sense.  

Now, this is Venus' `/etc/bind/named.conf.local` 

    zone "sistema.sol" {
            type slave; #Venus is a slave, and has to be declared as such
            file "/var/lib/bind/dns-slaves/sistema.sol";
            masters { 192.168.57.103; }; #Since Venus is a slave, its master has to be declared. The IP inside the {} is Tierra's
    };
    
    zone "57.168.192.in-addr.arpa" {
            type slave;
            file "/var/lib/bind/dns-slaves/192.168.57"; #This is the path to the file that stores the transfered resource registries from tierra that will be used by venus. It slightly differs from tierra's to make it more visible its a dependency
            masters { 192.168.57.103; };
    };
    
Now that all files have been configured for Tierra and Venus, the Resource Regitries must be defined. Bind comes with a file that contains the template to do this by just coping its content into another new file that will be that new registry. The registry has the following structure, which I will explain again using commented code and some extra data outside the code.  
The files to be created are `/var/lib/bind/sistema.sol.dns` and `/var/lib/bind/sistema.sol.rev`  

`/var/lib/bind/sistema.sol.dns`

    ;
    ;       sistema.sol
    ;
    $TTL    86400
    @    IN  SOA tierra.sistema.sol. vagrant.sistema.sol. (
                    1       ; Serial
                    3600    ; Refresh
                    1800    ; Retry
                    604800  ; Expire
                    7200 )  ; Negative Cache TTL
    ;
    @               IN      NS      tierra.sistema.sol.
    @               IN      NS      venus.sistema.sol.
    tierra.sistema.sol.     IN      A       192.168.57.103
    venus.sistema.sol.      IN      A       192.168.57.102
    marte.sistema.sol.      IN      A       192.168.57.104
    mercurio.sistema.sol.   IN      A       192.168.57.101
    ns1.sistema.sol.        IN      CNAME   tierra.sistema.sol.
    ns2.sistema.sol.        IN      CNAME   venus.sistema.sol.
    mail.sistema.sol.       IN      CNAME   marte.sistema.sol.
    sistema.sol.            IN      MX      10 marte.sistema.sol.

There are many elements in this files, so I will go through them one after the other in order  

- $TTL refers to the time to live of each request, followed by the amount in seconds for the TTL
- @ refers to this domain, its to refer to itself
- SOA refers to Star of Authority, it defines the server type and the main characteristics it posseses, followed by the FQDN of the Master Server for the domain (tierra.sistema.sol.), then the administrative user's email (vagrant.sistema.sol. in this case)
- Inside the () there are some parameters that were defined
    - Serial refers to the version number of the zone file, this number will be incremented each time it is modified, letting the slave servers know when they have to refresh their transfers
    - Refresh indicates the lapse of time for slave servers to contact their master to check if the zone file has changed
    - Retry serves the same purpose as refresh, stating how much time it has to pass for slave servers to try and contact the master if it is not responding
    - Expire refers to the amount of time the slaves will keep their zone configuration before discarding it and unabling themselves from operating. This happens only if the master server does not contact back
    - Negative cache TTL refers to the amount of time negative answers will be stored in this zone before being discarded. In this activity, this parameter had to be set to two hours (7200 seconds)  
- The next parameters refer to the elements in the server, these registries indicate specific information about the devices connected to this configuration
    - @ IN NS  Is used to declare the authorized servers for this zone. Each zone must contain at least one master server. This configuration has two Name Servers, the master Tierra and slave Venus. Their FDQNs are declared
    - (FDQN) IN A (IP address) is used to declare the IP Address that belongs to each device. In this case, we have 4 elements with IP addresses that correspond to each device in the configuration. Each has been declared and linked to their IP address in the registry
    - The CNAME registry is used to assign an alias to a domain name previously declared. In this case, the aliases ns1, ns2 and mail were assigned respectively to tierra, venus and martes as was requested by the activity
    - MX is the registry used to define the devices assigned to mail services in the domain. Marte was required to be the mail exchange device in this configuration.

As it can be seen, the configuration follows the requirements made by the activity, with each device having its corresponding assignment.  

For the reverse zone, there is a similar syntax, but with slight changes to it, since only the Name Servers have to be defined, and the IP addresses have to be linked to their respectie FDQNs.  

    ;
    ; 57.168.192
    ;
    $TTL    86400
    @       IN      SOA     tierra.sistema.sol. vagrant.sistema.sol. (
                    1       ; Serial
                    3600    ; Refresh
                    1800    ; Retry
                    604800  ; Expire
                    7200 ) ; Negative Cache TTL
    ;
    @       IN      NS      tierra.sistema.sol.
    @       IN      NS      venus.sistema.sol.
    @	IN	MX	10 marte.sistema.sol.
    103     IN      PTR     tierra.sistema.sol.
    102     IN      PTR     venus.sistema.sol.
    104     IN      PTR     marte.sistema.sol.
    101     IN      PTR     mercurio.sistema.sol.

In this case, we can see that the SOA registry is still the same, including he NS registries indicating the NS of the zone, which are still Tierra and Venus. Even the MX registry is the same.  
The difference comes at having to use the PTR registry, because, since we are defining the reverse lookup zone, resolvs in this way look for domain names based on IP addresses, so we use PTR to indicate to which domain name each IP address points.  
Each IP address points to its respective device.  
The last step in this activity is to issue command `sudo systemctl restart bind9` so that the service is restarted and the configuration reloaded.  


## Conclusion

To conclude this document, all the cofiguration that was discussed above can be found inside this repository and can be exported via Vagrant. The VagrantFile can be used in an initialized folder to `up` two vagrant computers ready to run the DNS server. In this initialized folder, drag the configuration files for the Master and Slave separatedly and then proceed to export them to their respective machines. The initialized vagrant folder is automatically a shared folder for both computers to access, so there will be no problems in this regard. Copy the configuration files with the intent to overwrite the ones in the computers, then reload the configuration. Finally, use the scripts, either the Linux one or the .bat one in Windows to test if the configuration is correct. Be warned that the Linux bash script isn't functional as of now, and you will require a bridged adapter for each computer to run the .bat file if you want the Host computer to be able to access the DNS server. Remember, the DNS configuration was built for an intranetwork. This summs up all this work, I tested all the possible resolvs manually since I could't get the scripts to work properly, but at least I know that there are no mistakes regarding the configuration, as all lookups and digs returned their correct answers.

#!/usr/bin/expect
set send_slow {10 .001}
spawn ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no vagrant@127.0.0.1 -p 2222

expect "password:"
send -s "vagrant\r";

# set up passwordless sudo
expect "vagrant-ubuntu-precise"
send -s "sudo su\r";
expect "password for vagrant:"
send -s "vagrant\r";
expect "vagrant-ubuntu-precise"
send -s "echo \"%sudo   ALL=NOPASSWD: ALL\" >> /etc/sudoers\r";
expect "vagrant-ubuntu-precise"
send -s "exit\r";

# set up public ssh key
expect "vagrant-ubuntu-precise"
send -s "mkdir .ssh\r";
expect "vagrant-ubuntu-precise"
send -s "wget -O .ssh/authorized_keys \"https://raw.github.com/mitchellh/vagrant/master/keys/vagrant.pub\"\r";
expect "vagrant-ubuntu-precise"
send -s "chmod 755 .ssh\r";
expect "vagrant-ubuntu-precise"
send -s "chmod 644 .ssh/authorized_keys\r";

#expect "vagrant-ubuntu-precise"
#send "sudo shutdown -h now\r";

#interact

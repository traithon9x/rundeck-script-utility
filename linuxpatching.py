#!/usr/bin/env python
#coding=utf-8
#maintainer TRAN KHANH HOANG
import platform
import sys
import os
import socket
import pwd
import subprocess
try:
    ipaddr = [l for l in ([ip for ip in socket.gethostbyname_ex(socket.gethostname())[2] if not ip.startswith("127.")][:1], [[(s.connect(('8.8.8.8', 53)), s.getsockname()[0], s.close()) for s in [socket.socket(socket.AF_INET, socket.SOCK_DGRAM)]][0][1]]) if l][0][0]
except:
    ipaddr = ''

#check tools exists EX: yum ,dnf,apt...
def is_tool(name):
    try:
        devnull = open(os.devnull)
        subprocess.Popen([name], stdout=devnull, stderr=devnull).communicate()
    except OSError as e:
        if e.errno == os.errno.ENOENT:
            return False
    return True

#check linux server os type
def linux_distribution():
  try:
    return platform.linux_distribution()
  except:
    return "N/A"

#get current username
def get_username():
    return pwd.getpwuid( os.getuid() )[ 0 ]

def ubuntu_security_update():
    print("###################")
    print("hostname: "+socket.gethostname())
    print("IP Address is: "+ ipaddr)
    # os.system("apt-get -y update")
    command = """apt-get -s dist-upgrade | grep "^Inst" | grep -i securi | awk -F " " {'print $2'} | xargs apt-get install -y"""
    if get_username() != 'root':
        command = """sudo -S apt-get -s dist-upgrade | grep "^Inst" | grep -i securi | awk -F " " {'print $2'} | sudo -S xargs apt-get install -y"""
    print ("run command: "+command)
    os.system(command)

def CentOS_security_update():
    print("###################")
    print("hostname: "+socket.gethostname())
    print("IP Address is: "+ ipaddr)
    command = "yum -y update --security"
    if get_username() != 'root':
        command = """sudo -S """+command
    print ("run command: "+command)
    os.system(command)

def Fedora_security_update():
    if is_tool('yum') == True:
        print("###################")
        print("hostname: "+socket.gethostname())
        print("IP Address is: "+ ipaddr)
        command = "yum -y update --security"
        if get_username() != 'root':
            command = """sudo -S """+command
        print ("run command: "+command)
        os.system(command)
    else:
        updateList = ''; x = ''
        for x in os.popen("dnf -q updateinfo list sec | awk '{print $3}'"):
            x = x.strip()
            updateList = updateList+' '+x
        if x != '':
            command = 'dnf update '+updateList
            if get_username() != 'root':
                command = """sudo -S """+command
            print ("run command: "+command)
            os.system(command)
        else:
            print ('No security updates available at this time!')


def SUSE_security_update():
    print("###################")
    print("hostname: "+socket.gethostname())
    print("IP Address is: "+ ipaddr)
    command = "zypper patch --category security"
    if get_username() != 'root':
        command = """sudo -S """+command
    print ("run command: "+command)
    os.system(command)
if __name__ == "__main__":
    if ('Ubuntu' in linux_distribution()) or ('Kali' in linux_distribution()) or ('Debian' in linux_distribution()):
        ubuntu_security_update()
    elif 'CentOS' in linux_distribution()[0]:
        CentOS_security_update()
    elif 'Fedora' in linux_distribution():
        Fedora_security_update()
    elif 'SUSE' in linux_distribution()[0]:
        SUSE_security_update()


#!/bin/bash
python <<HEREDOC
import subprocess
import os
import platform
import time
import threading
import time
import datetime as DT
import logging
import getpass
def notify(title, text):
	if platform.system() == 'Darwin':
	    os.system("""
	              osascript -e 'display notification "{}" with title "{}"'
	              """.format(text, title))
	else:
	    os.system("""
	              notify-send "{}: {}"
	              """.format(title,text))
def worker(cond):
    while True:
        with cond:
            cond.wait()
            time.sleep(1)
            if platform.system() == 'Darwin':
            	process = subprocess.Popen("pgrep kav", shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            else:
            	process = subprocess.Popen("pgrep kesl-gui", shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            kas_pid, err = process.communicate()
            notify("warning", "Your computer has been locked Internet. Please Turn on Kaspersky !!")
            if kas_pid:
                startnetwork()

def restart_kav_services():
	os.system("pgrep kav | xargs kill")
	os.system("launchctl unload /Library/LaunchDaemons/com.kaspersky.kav.plist")
	os.system("launchctl load /Library/LaunchDaemons/com.kaspersky.kav.plist")

def startnetwork():
	print ("start networking")
	logging.info("running: Start networking")
	if platform.system() == 'Darwin':
		os.system("ifconfig en0 up && ifconfig en1 up")
	else:
		os.system("/etc/init.d/networking start")

def stopnetwork():
	time.sleep(60)
	logging.info("running: Stop networking")
	notify("warning!!", "Your network disabled because kaspersky antivirus not running!")
	print ("stop networking")
	if platform.system() == 'Darwin':
		os.system("ifconfig en0 down && ifconfig en1 down")
	else:
		os.system("/etc/init.d/networking stop")


if __name__=='__main__':

	LOG = "/var/log/script-check-kaspersky.log"
	logging.basicConfig(filename=LOG, filemode="w", level=logging.DEBUG,format='%(asctime)s %(message)s', datefmt='%d/%m/%Y %H:%M:%S')
	logging.info("=====================================")
	logging.info("platform: " +platform.system())
	if platform.system() == 'Darwin':
		process = subprocess.Popen("pgrep kav", shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
	else:
		process = subprocess.Popen("pgrep kesl-gui", shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
	kas_pid, err = process.communicate()
	if not kas_pid:
		logging.info("Kaspersky PID not running! ")
		stopnetwork()
		cond = threading.Condition()
		t = threading.Thread(target=worker, args=(cond, ))
		t.daemon = True
		t.start()
		start = DT.datetime.now()
		while True:
		    now = DT.datetime.now()
		    if platform.system() == 'Darwin':
		    	process2 = subprocess.Popen("pgrep kav", shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
		    else:
		    	process2 = subprocess.Popen("pgrep kesl-gui", shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
		    kas_pid2, err = process2.communicate()
		    if ((now-start).total_seconds() > 60*60*60) or (kas_pid2)	: break

		    if now.second % 2:
		        with cond:
		            cond.notify()
	else:
		logging.info("Kaspersky PID running: "+str(kas_pid))
		startnetwork()
	logging.info("=====================================")

HEREDOC


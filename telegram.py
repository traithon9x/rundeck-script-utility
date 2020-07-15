#!/bin/bash
import requests
from datetime import datetime

def telegram_bot_sendtext(bot_message):

    bot_token = '878281365:AAG2svaudsnML2vCfoBXgLEUGeb0MhWbo2M'
    bot_chatID = '-352881967'
    send_text = 'https://api.telegram.org/bot' + bot_token + '/sendMessage?chat_id=' + bot_chatID + '&parse_mode=Markdown&text=' + bot_message
    response = requests.get(send_text)
    return response.json()
def get_message_sum():
    now = datetime.now()
    dt_string = now.strftime("%H:%M:%S %d/%m/%Y")
    jobname='`Report For Linux Mint_security_update '+ dt_string +'` \n'
    with open('/var/log/salt/job_log/ubuntu_security_update.sum', 'r') as reader:
        mesg = reader.read().replace("#"," ")
        fullmesg = jobname+mesg
        return fullmesg
if __name__=='__main__':
    telegram_bot_sendtext(get_message_sum())
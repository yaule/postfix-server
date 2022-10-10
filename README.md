# docker-postfix

docker postfix opendkim

easy to use.

# run

```sh
DOMAIN_NAME=youdomain.com
DKIMDOMAIN=email

docker run -it --rm -e DOMAIN_NAME=$DOMAIN_NAME -e SELECTOR_NAME=$DKIMDOMAIN -e DKIMDOMAIN=$DKIMDOMAIN --name sendmail-dkim --hostname $DOMAIN_NAME -v dkimkey:/etc/dkimkeys -p 25:25 sendmail-dkim
```
# set DNS 

look docker run logs, set DKIM / SPF record

# test

in docker,

```sh
sendemail -o message-charset=utf-8 -t youemail@email.com -f test@$DOMAIN_NAME -m "from test@$DOMAIN_NAME test email." -u 'test email : $(date)'
```
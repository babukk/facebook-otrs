#! /bin/sh
#---------------------------------------------------------------------------

./facebook-otrs-daemon.pl    \
    --log-file='log/facebook-otrs-daemon.log'  \
    --facebook-group-id=396739530678756 \
    --facebook-app-id=1205983529456424 \
    --facebook-app-secret='2ee29d3b6891fca1b37c53d50e863dde' \
    --facebook-access-token='EAARI1evg0ygBALMguQHIlPbiLo06YgZAfxEmDZC72qxgFdnk5128DbDfsKE2ZBU9IdOduTdD3R94ZCfkDVVSlKYAuQd2rrm7ypBnymollcuKTwJzgi1evuu7iNpLrL77lQarkF8bQRQZBCjgSf0ZAC' \
    --otrs-url='http://10.49.170.238:8000' \
    --otrs-login='tester' \
    --otrs-password='102938' \
    --otrs-queue='Postmaster::Facebook' \
    --otrs-customer-user='vasya.pupkin' \
    --db-type='SQLite' \
    --db-name='local_db.dat' \
    --http-local-addr='127.0.0.1' \
    --http-local-port='8888' \
    --fb-reload-interval=5

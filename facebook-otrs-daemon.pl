#! /usr/bin/perl -w
#----------------------------------------------------------------------------------

use strict;
use warnings;

use Getopt::Long qw( GetOptions );
use Data::Dumper;
use FacebookOTRS;

my $log_file;
my $facebook_group_id;
my $facebook_app_id;
my $facebook_app_secret;
my $facebook_access_token;
my $otrs_url;
my $otrs_login;
my $otrs_password;
my $otrs_queue;
my $db_type;
my $db_name;
my $db_username;
my $db_password;
my $http_local_addr;
my $http_local_port;
my $fb_reload_interval;
my $otrs_customer_user;

GetOptions(
    'log-file=s'              => \$log_file,
    'facebook-group-id=s'     => \$facebook_group_id,
    'facebook-app-id=s'       => \$facebook_app_id,
    'facebook-app-secret=s'   => \$facebook_app_secret,
    'facebook-access-token=s' => \$facebook_access_token,
    'otrs-url=s'              => \$otrs_url,
    'otrs-login=s'            => \$otrs_login,
    'otrs-password=s'         => \$otrs_password,
    'otrs-queue=s'            => \$otrs_queue,
    'otrs-customer-user=s'    => \$otrs_customer_user,
    'db-type=s'               => \$db_type,
    'db-name=s'               => \$db_name,
    'db-username=s'           => \$db_username,
    'db-password=s'           => \$db_password,
    'http-local-addr=s'       => \$http_local_addr,
    'http-local-port=s'       => \$http_local_port,
    'fb-reload-interval=s'    => \$fb_reload_interval,
);

my $facebook_otrs_daemon = FacebookOTRS->new({
    'log_file'                => $log_file,
    'facebook_group_id'       => $facebook_group_id,
    'facebook_app_id'         => $facebook_app_id,
    'facebook_app_secret'     => $facebook_app_secret,
    'facebook_access_token'   => $facebook_access_token,
    'otrs_url'                => $otrs_url,
    'otrs_login'              => $otrs_login,
    'otrs_password'           => $otrs_password,
    'otrs_queue'              => $otrs_queue,
    'otrs_customer_user'      => $otrs_customer_user,
    'db_name'                 => $db_name,
    'db_username'             => $db_username,
    'db_password'             => $db_password,
    'http_local_addr'         => $http_local_addr,
    'http_local_port'         => $http_local_port,
    'fb_reload_interval'      => $fb_reload_interval,
});

$facebook_otrs_daemon->run;

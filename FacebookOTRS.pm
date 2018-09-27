package FacebookOTRS;

use strict;
use warnings;

use DBI;
use HTTP::Daemon;
use HTTP::Status;
use DBD::SQLite;
use threads;
# use threads::shared;
use LWP::Simple;
use JSON;
use Data::Dumper;

use FacebookAPI;

our $VERSION = '0.1';

# ----------------------------------------------------------------------------------------------------------------------

sub new {
    my ($class, $params) = @_;

    my $self = {};

    while (my ($k, $v) = each %{$params}) {
        $self->{ $k } = $v;
    }

    $self->{ 'db_type' } = 'SQLite'             unless $self->{ 'db_type' };
    $self->{ 'http_local_addr' } = '127.0.0.1'  unless $self->{ 'http_local_addr' };
    $self->{ 'http_local_port' } = '8888'       unless $self->{ 'http_local_port' };
    $self->{ 'fb_reload_interval' } = 30        unless $self->{ 'fb_reload_interval' };

    bless $self, $class;

    if ($self->{ 'log_file' }) {
        require Log::Log4perl;

        my $log_conf =  '
                    log4perl.rootLogger              = DEBUG, LOG1
                    log4perl.appender.LOG1           = Log::Log4perl::Appender::File
                    log4perl.appender.LOG1.filename  = ' . $self->{ 'log_file' } . '
                    log4perl.appender.LOG1.mode      = append
                    log4perl.appender.LOG1.layout    = Log::Log4perl::Layout::PatternLayout
                    log4perl.appender.LOG1.layout.ConversionPattern = %d %p %m %n
        ';

        eval {
            $self->{ 'logger' } = Log::Log4perl->get_logger();
            Log::Log4perl::init(\$log_conf);
        };
    }

    return $self;
}

# ----------------------------------------------------------------------------------------------------------------------

sub run {
    my ($self) = @_;

    $self->{ 'dbh' } = $self->dbConnect;
    $self->dbPrepare;
    $self->dbSaveInitialToken;

    $self->{ 'fb_thread' } = threads->create(sub{ $self->fbThread; });
    $self->{ 'logger' }->info('run: Started.' . $@)  if ($self->{ 'logger' });

    $self->runHTTPserver;

    return;
}

# ----------------------------------------------------------------------------------------------------------------------

sub fbThread {
    my ($self) = @_;

    my $dbh = $self->dbConnect;
    my $fb = new FacebookAPI({
        'facebook_group_id' => $self->{ 'facebook_group_id' },
        'facebook_app_id' => $self->{ 'facebook_app_id' },
        'facebook_app_secret' => $self->{ 'facebook_app_secret' },
        'facebook_access_token' => $self->{ 'facebook_access_token' },
        'dbh' => $dbh,
        'otrs_url' => $self->{ 'otrs_url' },
        'otrs_login' => $self->{ 'otrs_login' },
        'otrs_password' => $self->{ 'otrs_password' },
        'otrs_queue' => $self->{ 'otrs_queue' },
        'otrs_customer_user' => $self->{ 'otrs_customer_user' },
        'logger' => $self->{ 'logger' },
    });

    $fb->getToken;

    while (1) {
        $fb->getNewPosts;
        sleep $self->{ 'fb_reload_interval' };
    }
}

# ----------------------------------------------------------------------------------------------------------------------

sub runHTTPserver {
    my ($self) = @_;

    my $daemon = HTTP::Daemon->new(
        LocalAddr => $self->{ 'http_local_addr' },
        LocalPort => $self->{ 'http_local_port' },
        Reuse  => 1,
    ) || die;


    while (my $c = $daemon->accept) {
        # print "accepted\n";
        threads->create(sub { $self->httpServerThread(@_) }, $c)->detach;
        $c->close;
        undef $c;
    }
}

# ----------------------------------------------------------------------------------------------------------------------

sub httpServerThread {
    my ($self, $conn) = @_;

    $conn->daemon->close;

    while (my $req = $conn->get_request) {
        if ($req->method eq "POST") {
            print 'httpServerThread: req => ', Dumper($req);
            print $req->url, "\n";
            if ($req->url =~ /\/fb\/add_comment/) {

                my $json_obj = JSON->new->allow_nonref;

                my $data = $req->{ '_content' };
                # print Dumper($data);

                my $json = $json_obj->decode($data);
                my $resp = $self->fbAddComment($json);

                $conn->send_basic_header;
                $conn->print("Content-Type: application/json");
                $conn->send_crlf;
                $conn->send_crlf;
                $conn->print($resp);
            }
            elsif ($req->url =~ /\/fb\/close_ticket/) {

                my $json = decode_json($req->{ '_content' });
                $self->fbCloseTicket($json);

                $conn->send_basic_header;
                $conn->print("Content-Type: application/json");
                $conn->send_crlf;
                $conn->send_crlf;
            }
            else {
                $conn->send_error(RC_FORBIDDEN);
            }
            last;
        }
        else {
            $conn->send_error(RC_FORBIDDEN);
        }
    }

    $conn->close;
    undef $conn;

    return;
}

# ----------------------------------------------------------------------------------------------------------------------

sub fbAddComment {
    my ($self, $data) = @_;

    my $dbh = $self->dbConnect;

    my $fb = new FacebookAPI({
        'facebook_group_id' => $self->{ 'facebook_group_id' },
        'facebook_app_id' => $self->{ 'facebook_app_id' },
        'facebook_app_secret' => $self->{ 'facebook_app_secret' },
        'facebook_access_token' => $self->{ 'facebook_access_token' },
        'dbh' => $dbh,
    });

    # $fb->getToken;
    # print "fbAddComment: token = ", $fb->{ 'token' }, "\n";

    my $ticket_id = $data->{ 'ticket_id' };
    my $message = $data->{ 'message' };

    my $post_id = $fb->getPostByTicket($ticket_id);

    print "fbAddComment: post_id = ", $post_id, "\n";
    print "fbAddComment: message = ", $message, "\n";

    my $resp = $fb->commentPost($post_id, $message);

    undef $fb;

    return $resp;
}

# ----------------------------------------------------------------------------------------------------------------------

sub fbCloseTicket {
    my ($self) = @_;

    my $dbh = $self->dbConnect;

    my $fb = new FacebookAPI({
        'facebook_group_id' => $self->{ 'facebook_group_id' },
        'facebook_app_id' => $self->{ 'facebook_app_id' },
        'facebook_app_secret' => $self->{ 'facebook_app_secret' },
        'facebook_access_token' => $self->{ 'facebook_access_token' },
        'dbh' => $dbh,
    });

    $fb->getToken;
    # print "fbCloseTicket: token = ", $fb->{ 'token' }, "\n";


    undef $fb;

    return;
}

# ----------------------------------------------------------------------------------------------------------------------

sub dbConnect {
    my ($self) = @_;

    my $dbh;

    eval {
        $dbh = DBI->connect(
            'dbi:' . $self->{ 'db_type' } . ':dbname=' . $self->{ 'db_name' },
            { AutoCommit => 0, RaiseError => 1, PrintError =>1, }
        );
    };
    if ($@) {
        $self->{ 'logger' }->info('dbConnect: SQL error => ' . $@)  if $self->{ 'logger' };
    }

    return $dbh;
}

# ----------------------------------------------------------------------------------------------------------------------

sub dbPrepare {
    my ($self) = @_;

    eval {
        $self->{ 'dbh' }->do("
            CREATE TABLE IF NOT EXISTS  fb_posts (
                post_id  VARCHAR(64),
                dt  TIMESTAMP,
                ticket_id  INTEGER,
                status  INTEGER  NOT NULL DEFAULT 0     /* 1 - new (ticket does not exist yet),
                                                           2 - ticket created,
                                                           3 - ticket commented in OTRS,
                                                           4 - ticket commented in FB,
                                                           5 - ticket closed */
            );

            CREATE TABLE IF NOT EXISTS  fb_access (
                token  VARCHAR(512)
            );
            "
        );
    };
    if ($@) {
        $self->{ 'logger' }->info('dbPrepare: SQL error => ' . $@)  if $self->{ 'logger' };
    }

    eval {
        $self->{ 'dbh' }->do("

            CREATE TABLE IF NOT EXISTS  fb_access (
                token  VARCHAR(512)
            );
            "
        );
    };
    if ($@) {
        $self->{ 'logger' }->info('dbPrepare: SQL error => ' . $@)  if $self->{ 'logger' };
    }

    return;
}

# ----------------------------------------------------------------------------------------------------------------------

sub dbSaveInitialToken {
    my ($self) = @_;

    my $sth;
    my $n_token = 0;

    eval {
        $sth = $self->{ 'dbh' }->prepare(" SELECT  count(*)  FROM  fb_access  WHERE  token IS NOT NULL ");
        $sth->execute;
        ($n_token) = $sth->fetchrow_array;
        $sth->finish;
        undef $sth;
    };
    if ($@) {
        $self->{ 'logger' }->info('dbSaveInitialToken: SQL error => ' . $@)  if $self->{ 'logger' };
        return;
    }

    unless ($n_token) {
        eval {
            $sth = $self->{ 'dbh' }->prepare(" INSERT INTO  fb_access  (token)  VALUES  (?) ");
            $sth->execute($self->{ 'facebook_access_token' });
            $sth->finish;
            undef $sth;
        };
        if ($@) {
            $self->{ 'logger' }->info('dbSaveInitialToken: SQL error => ' . $@)  if $self->{ 'logger' };
            return;
        }
    }

}

1;

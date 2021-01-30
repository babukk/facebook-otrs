package FacebookAPI;

use strict;
use warnings;

use Facebook::OpenGraph;
use LWP::Simple;
use LWP::UserAgent;
use HTTP::Request::Common qw{ POST };
use JSON;
use URI;
use Encode qw(decode);
use Data::Dumper;

use OTRSapi;

sub new {
    my ($class, $params) = @_;

    my $self = {};

    while (my ($k, $v) = each %{$params}) {
        $self->{ $k } = $v;
    }

    $self->{ 'fb_graph_url' } = 'https://graph.facebook.com/';

    bless $self, $class;

    return $self;
}

sub getToken {
    my ($self) = @_;

    my $token_ref = Facebook::OpenGraph->new({
        app_id => $self->{ 'facebook_app_id' },
        secret => $self->{ 'facebook_app_secret' },
    })->get_app_token;

    $self->{ 'token' } = $token_ref->{access_token};

    return $self->{ 'token' };
}

sub getNewPosts {
    my ($self) = @_;

    my $uri = new URI($self->{ 'fb_graph_url' } . $self->{ 'facebook_group_id' } . '/feed');
    $uri->query_form({ 'access_token' => $self->{ 'token' }, });

    my $resp = get($uri);
    # print "uri => ", $uri, "\n";
    # print Dumper($resp);

    my $json_obj = JSON->new->allow_nonref;
    my $json_data = $json_obj->decode($resp);
    # print "json_data => ", Dumper($json_data), "\n";

    my $otrs_api = new OTRSapi({
        'otrs_url' => $self->{ 'otrs_url' },
        'otrs_login' => $self->{ 'otrs_login' },
        'otrs_password' => $self->{ 'otrs_password' },
        'otrs_queue' => $self->{ 'otrs_queue' },
        'otrs_customer_user' => $self->{ 'otrs_customer_user' },
        'logger' => $self->{ 'logger' },
    });

    foreach my $j_data (@{$json_data->{ 'data' }}) {
        # print Dumper($j_data);
        next  if $self->ticketByPostExists($j_data->{ 'id' });
        if ($self->recordExists($j_data->{ 'id' })) {
            $self->{ 'logger' }->info('getNewPosts: Record for post id:' . $j_data->{ 'id' } . ' already exists.')  if $self->{ 'logger' };
            next;
        }
        my $ticket_id = $otrs_api->createTicket($j_data->{ 'id' }, $j_data->{ 'updated_time' }, $j_data->{ 'message' });
        $self->savePost($j_data->{ 'id' }, $j_data->{ 'updated_time' }, $ticket_id);
        # print $j_data->{ 'id' }, "\n";
    }

    return;
}

sub ticketByPostExists {
    my ($self, $id) = @_;

    my $sth;
    my $ticket_id = undef;
    eval {
        $sth = $self->{ 'dbh' }->prepare(" SELECT  ticket_id  FROM  fb_posts  WHERE  post_id = ? ");
        $sth->execute($id);
        ($ticket_id) = $sth->fetchrow_array;
        $sth->finish;
        undef $sth;
    };
    if ($@) {
        $self->{ 'logger' }->error('ticketByPostExists: SQL error => ' . $@)  if $self->{ 'logger' };
    }

    return $ticket_id;
}

sub getPostByTicket {
    my ($self, $id) = @_;

    my $sth;
    my $post_id = undef;
    eval {
        $sth = $self->{ 'dbh' }->prepare(" SELECT  post_id  FROM  fb_posts  WHERE  ticket_id = ? ");
        $sth->execute($id);
        ($post_id) = $sth->fetchrow_array;
        $sth->finish;
        undef $sth;
    };
    if ($@) {
        $self->{ 'logger' }->error('getPostByTicket: SQL error => ' . $@)  if $self->{ 'logger' };
    }

    return $post_id;
}

sub recordExists {
    my ($self, $id) = @_;

    my $sth;
    my $nn = 0;
    eval {
        $sth = $self->{ 'dbh' }->prepare(" SELECT  count(*)  FROM  fb_posts  WHERE  post_id = ? ");
        $sth->execute($id);
        ($nn) = $sth->fetchrow_array;
        $sth->finish;
        undef $sth;
    };
    if ($@) {
        $self->{ 'logger' }->error('recordExists: SQL error => ' . $@)  if $self->{ 'logger' };
    }

    return $nn;
}

sub savePost {
    my ($self, $id, $dt, $ticket_id) = @_;

    my $status = (defined $ticket_id ? 2 : 1);
    my $sth;
    eval {
        $sth = $self->{ 'dbh' }->prepare(" INSERT INTO  fb_posts  (post_id, dt, status, ticket_id)  VALUES  (?, ?, ?, ?) ");
        $sth->execute($id, $dt, $status, $ticket_id);
        $sth->finish;
        undef $sth;
    };
    if ($@) {
        $self->{ 'logger' }->error('savePost: SQL error => ' . $@)  if $self->{ 'logger' };
    }

    return;
}

sub getAccessToken {
    my ($self) = @_;

    my $sth;
    my $token;

    eval {
        $sth = $self->{ 'dbh' }->prepare(" SELECT  token  FROM  fb_access ");
        $sth->execute;
        ($token) = $sth->fetchrow_array;
        $sth->finish;
        undef $sth;
    };
    if ($@) {
        $self->{ 'logger' }->error('getAccessToken: SQL error => ' . $@)  if $self->{ 'logger' };
        return undef;
    }

    # print "getAccessToken: token (from DB) = ", $token, "\n";

    my $uri = new URI($self->{ 'fb_graph_url' } . 'oauth/access_token');
    $uri->query_form({
        'client_id' => $self->{ 'facebook_app_id' },
        'client_secret' => $self->{ 'facebook_app_secret' },
        'grant_type' => 'fb_exchange_token',
        'fb_exchange_token' => $token,
    });

    # print "getAccessToken: uri => ", Dumper($uri);

    my $ua = LWP::UserAgent->new();
    my $resp = $ua->get($uri);

    my %resp_arr = split /[=&]/, $resp->decoded_content;
    $token = $resp_arr{ 'access_token' };

    eval {
        $sth = $self->{ 'dbh' }->prepare(" UPDATE  fb_access  SET  token = ? ");
        $sth->execute($token);
        $sth->finish;
        undef $sth;
    };
    if ($@) {
        $self->{ 'logger' }->error('getAccessToken: SQL error => ' . $@)  if $self->{ 'logger' };
    }

    return $token;
}

sub commentPost {
    my ($self, $post_id, $message) = @_;

    my $token = $self->getAccessToken;

    my $ua = LWP::UserAgent->new();
    my $uri = new URI($self->{ 'fb_graph_url' } . $post_id . '/comments');
    $uri->query_form({
        'access_token' => $token,
        'message' => decode('UTF-8', $message),
    });

    # print "uri => ", Dumper($uri), "\n";

    my $response = $ua->post($uri, 'Content-type'   => 'text/plain; charset=utf-8');
    my $content  = $response->decoded_content();

    $self->{ 'logger' }->info('commentPost: post_id = ' . $post_id, '; message = ' . $message)  if $self->{ 'logger' };

    print "response => ", Dumper($response), "\n";
    print "content = ", $content, "\n";

    return $content;
}

1;

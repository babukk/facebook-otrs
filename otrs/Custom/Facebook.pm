package Facebook;

use strict;
use warnings;

use LWP::UserAgent;
use Encode qw(encode);
use URI;
use JSON;

use lib qw( . /opt/otrs/Custom );
use FacebookConfig;

=cut
use Log::Log4perl;
use Data::Dumper;

my  $log_conf = '/opt/otrs/etc/log4perl.conf';
my  $logger = Log::Log4perl->get_logger();
Log::Log4perl::init( $log_conf );
=cut

# ----------------------------------------------------------------------------------------

sub addComment {
    my ($ticket_number, $message, $article_type_id) = @_;

    if (grep /^$article_type_id$/, FacebookConfig::FB_OTRS_ARTICLE_IDS) {

        my $ua = LWP::UserAgent->new();
        my $uri = new URI(FacebookConfig::FB_ADD_COMMENT_SVC);

        my $json_obj = JSON->new->allow_nonref;
        my $json_str = $json_obj->encode({ 'ticket_id' => $ticket_number, 'message' => encode('UTF-8', $message), });

        # $logger->info('addComment: json_str = ' . $json_str);

        my $response = $ua->post($uri, 'Content-type' => 'application/json; charset=UTF-8', 'Content' => $json_str);

        # $logger->info('addComment: response => ' . Dumper($response));

        my $content  = $response->decoded_content();
    }

    return;
}

1;

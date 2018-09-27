use Test::More qw[no_plan];
use strict;
$^W = 1;

use_ok 'FacebookOTRS';

ok(
    my $daemon = FacebookOTRS->new({
    })
,
'Can-t create instance of FacebookOTRS.pm'
)

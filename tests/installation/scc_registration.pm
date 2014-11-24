#!/usr/bin/perl -w
use strict;
use base "y2logsstep";

use testapi;

sub run() {
    my $self = shift;
    assert_screen( "scc-registration", 30 );
    if (get_var("SCC_EMAIL") && get_var("SCC_REGCODE") && (!get_var("SCC_REGISTER") || get_var("SCC_REGISTER") eq 'installation')) {

        send_key "alt-e";    # select email field
        type_string get_var("SCC_EMAIL");
        send_key "tab";
        type_string get_var("SCC_REGCODE");
        send_key $cmd{"next"}, 1;
        my @tags = qw/local-registration-servers registration-online-repos/;
        while ( my $ret = check_screen(\@tags, 60 )) {
            if ($ret->{needle}->has_tag("local-registration-servers")) {
                send_key $cmd{ok};
                shift @tags;
                next;
            }
            last;
        }

        assert_screen("registration-online-repos", 1);
        send_key "alt-y", 1;    # want updates

        assert_screen("module-selection", 10);
        send_key $cmd{"next"}, 1;
    }
    else {
        send_key "alt-s", 1;     # skip SCC registration
        if ( check_screen( "scc-skip-reg-warning", 10 ) ) {
            send_key "alt-y", 1;    # confirmed skip SCC registration
        }
    }
    return 0;
}

1;

# vim: set sw=4 et:

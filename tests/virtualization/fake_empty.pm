use base 'basetest';
use strict;
use warnings;
use testapi;
use autotest;
use POSIX qw(SIGTERM);
sub run {
    my $self = shift;
    record_info("Empty test is not allowed!", "I am a fake test.");
    # none of below works to make the test cancelled status in a build's job group view
    #$self->skip_if_not_running;
    #$autotest::handle_sigterm('TERM');
    #kill SIGTERM, $$;
    #$autotest::current_test->result('canceled');
    #$autotest::current_test->save_test_result();
}

1;

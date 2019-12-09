# SUSE's openQA tests
#
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: virt_autotest: the initial version of virtualization automation test in openqa, with kvm support fully, xen support not done yet
# Maintainer: alice <xlai@suse.com>

use strict;
use warnings;
use base "virt_autotest_base";
use testapi;
use virt_utils;
use utils;


sub run {
	assert_script_run("echo start fail_moduleA.pm");
	die "die on purpose to check if test continue to next module";
}


sub post_fail_hook {
	#force_soft_failure("let test continue...");
        script_run("echo fail_moduleA.pm post_fail_hook DONE");
	save_screenshot;
}

sub test_flags {
    return {fatal => 0};
}
1;


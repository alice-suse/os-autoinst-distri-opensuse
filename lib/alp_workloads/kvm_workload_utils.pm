# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: This file provides the utility functions for kvm workload container.
# Maintainer: alice <xlai@suse.com>, qe-virt@suse.de

package alp_workloads::kvm_workload_utils;

use base Exporter;
use Exporter;
use strict;
use warnings;
use testapi;
use Utils::Architectures;
use Utils::Backends qw(use_ssh_serial_console);
use ipmi_backend_utils;
use utils;
use virt_autotest::virtual_network_utils qw(clean_all_virt_networks);
use virt_autotest::utils qw(ssh_setup);

our @EXPORT = qw(
  set_ct_engine
  set_kvm_image
  pull_kvm_container
  config_host_and_kvm_container
  cleanup_host_and_kvm_container
  start_kvm_container
  enter_kvm_container_sh
  exit_kvm_container
  install_tools_within_kvm_container
  setup_services_within_kvm_container
  collect_kvm_container_setup_logs
  setup_kvm_container_from_scratch
  clean_and_resetup_kvm_container
);

# Container engine: can be podman(default), docker(not tested)
our $ct_engine = "podman";

my $DEFAULT_KVM_IMAGE = "registry.opensuse.org/suse/alp/workloads/tumbleweed_containerfiles/suse/alp/workloads/kvm:latest";
our $kvm_image = $DEFAULT_KVM_IMAGE;

sub set_ct_engine {
    $ct_engine = shift;

    die "Container engine can only be set to podman or docker!" if ($ct_engine ne "podman" && $ct_engine ne "docker");
}

sub set_kvm_image {
    my $_image = shift;

    # Allow customization in case of special test needs
    if ($_image ne $DEFAULT_KVM_IMAGE) {
        $kvm_image = $_image;
        record_info("The kvm container image has been changed from default!", "Now test is using kvm image: $kvm_image.");
    }
}

sub pull_kvm_container {
    # Ensure large enough time is given to download
    # TODO: uncomment once automation is done
    # assert_script_run("$ct_engine pull $kvm_image", 1800/get_var('TIMEOUT_SCALE', 1));
    record_info("Kvm container image is successfully downloaded.", "Image: $kvm_image.");

}

sub config_host_and_kvm_container {
    # Copy contents from kvm container to host to set it up
    assert_script_run("clear; $ct_engine container runlabel install $kvm_image");
    save_screenshot;

    # Replace /etc/kvm-container.conf IMAGE value with $kvm_image if non-default
    if ($kvm_image ne $DEFAULT_KVM_IMAGE) {
        assert_script_run("cp /etc/kvm-container.conf /etc/kvm-container.conf.org");
        assert_script_run(q@sed -i 's#^\s*IMAGE=.*$#IMAGE=@ . $kvm_image . q@#g' /etc/kvm-container.conf@);
        assert_script_run("grep ^IMAGE= /etc/kvm-container.conf");
        save_screenshot;
        record_info("/etc/kvm-container.conf default IMAGE is changed!", "New value is IMAGE=$kvm_image.");
    }

    # Share /dev/sshserial from host to kvm container for let openqa root-ssh console works
    assert_script_run("cp /usr/local/bin/kvm-container-manage.sh /usr/local/bin/kvm-container-manage.sh.org");
    assert_script_run(q@sed -i 's#podman create#podman create --volume /dev/sshserial:/dev/sshserial #g' /usr/local/bin/kvm-container-manage.sh@);
    script_run("diff /usr/local/bin/kvm-container-manage.sh /usr/local/bin/kvm-container-manage.sh.org");
    save_screenshot;
    record_info("kvm-container-manage.sh has been changed to share sol console needed device with kvm container.");
    assert_script_run("kvm-container-manage.sh create");
    save_screenshot;
    record_info("KVM container is created!");
}

sub cleanup_host_and_kvm_container {
    assert_script_run("if $ct_engine ps | grep libvirtd; then kvm-container-manage.sh stop;fi");
    assert_script_run("if $ct_engine ps --all | grep libvirtd; then kvm-container-manage.sh rm;fi");
    assert_script_run("if which kvm-container-manage.sh;then kvm-container-manage.sh uninstall;fi");
    save_screenshot;
    record_info("KVM container is removed and container related files are removed from host");
}

sub start_kvm_container {
    assert_script_run("$ct_engine start libvirtd");
    save_screenshot;
    assert_script_run("$ct_engine ps | grep -i libvirtd | grep Up");
    save_screenshot;
}

sub enter_kvm_container_sh {
    enter_cmd("clear;$ct_engine exec -ti libvirtd bash", 15);    # interactive mode, so no return immediately
    save_screenshot;
    assert_screen('in-libvirtd-container-bash');
    assert_script_run("echo Hello from libvirtd container");
    save_screenshot;

    assert_script_run("ip a");
    save_screenshot;
    record_info('Please check if it is from within libvirtd container');

}

sub exit_kvm_container {
    assert_script_run("clear");
    assert_screen('in-libvirtd-container-bash');
    enter_cmd("exit");
    wait_still_screen 3;
    save_screenshot;
    assert_screen('back-to-host-shell');

}

sub install_tools_within_kvm_container {
    my $_tools_to_install = shift;

    $_tools_to_install = "wget curl screen xmlstarlet yast2-schema python3 nmap openssh hostname gawk supportutils" if (!$_tools_to_install);

    assert_script_run("clear");
    assert_screen('in-libvirtd-container-bash');
    zypper_call("in $_tools_to_install", 120);
    save_screenshot;
    record_info("Successfully installed test needed tools within VT container.");

}

sub setup_services_within_kvm_container {
    assert_script_run("clear");
    assert_screen('in-libvirtd-container-bash');

    # Stop all pre-start virtual network
    clean_all_virt_networks;
    # Setup nat virtual network as needed
    my $_vnet_loc = "/etc/libvirt/qemu/networks/alp-nat-vnet.xml";
    assert_script_run("curl " . data_url("virt_autotest/alp-nat-vnet.xml") . " -o $_vnet_loc");
    assert_script_run("virsh net-define $_vnet_loc");
    assert_script_run("virsh net-autostart test-virt-net");
    assert_script_run('virsh net-start test-virt-net');
    save_screenshot;
    record_info("Successfully setup nat virtual network test-virt-net for automation test.", script_output("ip a"));
}

sub setup_kvm_container_from_scratch {
#    pull_kvm_container;
#    config_host_and_kvm_container;
#    start_kvm_container;
    enter_kvm_container_sh;
#    install_tools_within_kvm_container;
    virt_autotest::utils::ssh_setup('/root/.ssh/id_rsa');
#    setup_services_within_kvm_container;
}

sub clean_and_resetup_kvm_container {
    #cleanup_host_and_kvm_container;
    setup_kvm_container_from_scratch;
}

sub collect_kvm_container_setup_logs {
    reset_consoles;
    use_ssh_serial_console;

    my $_kvm_container_log_file = "/tmp/kvm_container.log";
    my @cmds = (
        "$ct_engine ps --all",
        "$ct_engine images -a --digests",
        "$ct_engine inspect libvirtd",
        "$ct_engine logs libvirtd"
    );

    script_run("rm $_kvm_container_log_file");
    foreach my $cmd (@cmds) {
        script_run("echo \"Executing $cmd:\" >>$_kvm_container_log_file");
        script_run("$cmd >> $_kvm_container_log_file 2>&1");
        script_run(qq@echo "\n\n" >> @ . $_kvm_container_log_file);
    }
    save_screenshot;
    upload_logs("$_kvm_container_log_file");

    upload_logs("/etc/kvm-container.conf");
    upload_logs("/usr/local/bin/kvm-container-manage.sh");
    upload_logs("/etc/libvirt/qemu/networks/alp-nat-vnet.xml");
    save_screenshot;
}
1;


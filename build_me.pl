#!/usr/bin/env perl
use strict;
use warnings;

use File::Spec::Functions qw(catfile catdir curdir);
use Capture::Tiny qw(capture_stdout);

my ($nargs) = $#ARGV + 1;
if ( glob($nargs) >= 3 ) {
    print("Usage: $0 target\n\n");
    print(
"This program will build the optimized version of OpenWrt for the selected [target].\n"
    );
    exit 1;
}

use constant {
    DIST              => 'NoTengoBattery',
    DOWNLOAD_ROOT_URL => 'downloads.notengobattery.com',
    ISSUES            => 'issues',
    LINUX_TARGET      => 'target/linux',
    PROJECTS          => 'projects',
    PROJECT_NAME      => "openwrt-" . $ARGV[0],
    RELEASES          => 'releases',
    RELEASE_NOTES     => 'release-notes',
    ROOT_URL          => 'notengobattery.com',
    TARGET            => $ARGV[0],
    SUBTARGET         => $ARGV[1] || 'generic',
    VERSION           => 'v3.0.0-rc4'
};

my ($releaseURL) =
  'https://' . catdir( ROOT_URL, PROJECTS, PROJECT_NAME, RELEASES, VERSION );
my ($issuesURL) =
  'https://'
  . catdir( ROOT_URL, PROJECTS, PROJECT_NAME, RELEASES, VERSION, ISSUES );
my ($downloadURL) =
  'https://' . catdir( DOWNLOAD_ROOT_URL, PROJECTS, 'openwrt-' . VERSION );
my ($supportURL) =
  'https://'
  . catdir( ROOT_URL, PROJECTS, PROJECT_NAME, RELEASES, VERSION,
    RELEASE_NOTES );
my ($curDir)            = curdir();
my ($dSeed)             = catdir( glob($curDir),    'seeds' );
my ($dScripts)          = catdir( glob($curDir),    'scripts' );
my ($linuxTarget)       = catdir( glob($curDir),    LINUX_TARGET );
my ($fConfig)           = catfile( glob($curDir),   '.config' );
my ($fConfigSeed)       = catfile( glob($curDir),   'config.seed' );
my ($fCommonSeed)       = catfile( glob($dSeed),    'common.seed' );
my ($fFeaturesSeed)     = catfile( glob($dSeed),    'features.seed' );
my ($fKernelCommonSeed) = catfile( glob($dSeed),    'common-kernel.seed' );
my ($fKernelSeed)       = catfile( glob($dSeed),    'kernel.seed' );
my ($fKernelTargetSeed) = catfile( glob($dSeed),    TARGET . '-kernel.seed' );
my ($fPackagesSeed)     = catfile( glob($dSeed),    'packages.seed' );
my ($fSubTargetSeed)    = catfile( glob($dSeed),    TARGET . '-' . SUBTARGET . '.seed' );
my ($fTargetSeed)       = catfile( glob($dSeed),    TARGET . '.seed' );
my ($fScriptDiff)       = catfile( glob($dScripts), 'diffconfig.sh' );
my ($kconfg) = readpipe( sprintf "find %s -type f -path '*/%s/*config-*.*'",
    $linuxTarget, TARGET );

open( COMMON_SEED, "<", glob($fCommonSeed) )
  or die qq(Could not open file '$fCommonSeed' : $!);
open( FEATURES_SEED, "<", glob($fFeaturesSeed) )
  or die qq(Could not open file '$fFeaturesSeed' : $!);
open( KERNEL_SEED, "<", glob($fKernelSeed) )
  or die qq(Could not open file '$fKernelSeed' : $!);
open( TARGET_SEED, "<", glob($fTargetSeed) )
  or die qq(Could not open file '$fTargetSeed' : $!);
open( SUBTARGET_SEED, "<", glob($fSubTargetSeed) )
  or die qq(Could not open file '$fSubTargetSeed' : $!);
open( PACKAGE_SEED, "<", glob($fPackagesSeed) )
  or die qq(Could not open file '$fPackagesSeed' : $!);
open( KERNEL_COMMON_SEED, "<", glob($fKernelCommonSeed) )
  or die qq(Could not open file '$fKernelCommonSeed' : $!);
open( KERNEL_TARGET_SEED, "<", glob($fKernelTargetSeed) )
  or die qq(Could not open file '$fKernelTargetSeed' : $!);
open( CONFIG_SEED, ">", glob($fConfigSeed) )
  or die qq(Could not open file '$fConfigSeed' : $!);
open( CONFIG, ">", glob($fConfig) )
  or die qq(Could not open file '$fConfig' : $!);
open( KCONFIG, ">>", glob($kconfg) )
  or die qq(Could not open file '$kconfg' : $!);

printf( CONFIG "%s=\"%s\"\n", "CONFIG_VERSION_BUG_URL",     glob($issuesURL) );
printf( CONFIG "%s=\"%s\"\n", "CONFIG_VERSION_DIST",        DIST );
printf( CONFIG "%s=\"%s\"\n", "CONFIG_VERSION_HOME_URL",    glob($releaseURL) );
printf( CONFIG "%s=\"%s\"\n", "CONFIG_VERSION_NUMBER",      VERSION );
printf( CONFIG "%s=\"%s\"\n", "CONFIG_VERSION_REPO",        glob($downloadURL) );
printf( CONFIG "%s=\"%s\"\n", "CONFIG_VERSION_SUPPORT_URL", glob($supportURL) );
print( CONFIG <COMMON_SEED>,    "\n" );
print( CONFIG <FEATURES_SEED>,  "\n" );
print( CONFIG <KERNEL_SEED>,    "\n" );
print( CONFIG <TARGET_SEED>,    "\n" );
print( CONFIG <SUBTARGET_SEED>, "\n" );
print( CONFIG <PACKAGE_SEED>,   "\n" );
close(CONFIG);

print( KCONFIG <KERNEL_COMMON_SEED>, "\n" );
print( KCONFIG <KERNEL_TARGET_SEED>, "\n" );
close(KCONFIG);

system("./scripts/feeds update -a");
system("./scripts/feeds install -a");
system("make defconfig");
system("make kernel_oldconfig");
print( CONFIG_SEED readpipe("$fScriptDiff") );

print("\n\nProject configured. Now is a good moment to build.\n")

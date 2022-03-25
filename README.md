# rancid-nortel
RANCID scripts for Nortel BayStack devices

These files add support for Bay Networks/Nortel/Avaya BayStack/BPS/ERS switches to RANCID.  I based these changes on ones we've been running in production for over a decade and I've tested this extensively on models BPS 2000, 470, and ERS 25xx/45xx/55xx/56xx.

Initially I copied `clogin` to `bslogin`, but I've included a patch for the original rancid-3.9 `clogin` because I believe it should be safe to apply to the original and eliminate the need for a separate login script.  I rearranged a few conditionals related to Extreme support to make the logic easier for the BayStack and other future differences.

It was a PITA to get past the BayStack login banner, but I finally found a workable solution that should hopefully not interfere with other device types and should support BayStacks that have the stock banner, a custom banner, or the banner turned off.  The only potential concern for impact to non-BayStack devices is the matching on `##+` used to skip past the banner to avoid it being interpreted as a `#` prompt character.  I'm now running this in production as my `clogin` and so far there have been no impacts to Aruba devices, the only other devices I have that use clogin.

## Instructions:

1. Copy `baystack.pm` to the same place where you have your RANCID perl modules or to one of the directories listed in your `rancid.conf` PERL5LIB environment variable, e.g.:

  ```
PERL5LIB="/usr/share/perl5/vendor_perl/rancid:/usr/local/share/perl5/rancid"; export PERL5LIB
  ```

2. Copy `bslogin` to the same place where you have your RANCID clogin file or to one of the directories listed in your `rancid.conf` PATH environment variable, e.g.:

  ```
PATH=/usr/libexec/rancid:/usr/local/libexec/rancid:/usr/bin:/usr/sbin:/usr/local/bin; export PATH
  ```
3. Make the `bslogin` script executable:

  ```
chmod 755 bslogin
  ```

4. Append the contents of `rancid.types.conf.baystack` to your existing `rancid.types.conf`.

5. Configure `router.db` entries with type `baystack`, e.g.:

  ```
bps-switch;baystack;up
470-switch;baystack;up
ers-5520-switch;baystack;up
  ```

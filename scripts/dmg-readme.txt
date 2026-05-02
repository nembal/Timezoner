Install TimeZoner
=================

1. Drag TimeZoner.app onto the Applications folder.

2. Open Terminal and paste this one command:

       xattr -cr /Applications/TimeZoner.app

   (If you put the app somewhere other than /Applications,
   change the path — e.g. ~/Applications/TimeZoner.app.)

   Terminal will not print anything when it works — that's normal.

3. Launch TimeZoner from Applications or Spotlight.


Why step 2?
-----------
macOS tags anything downloaded from a browser with a "quarantine"
flag, which triggers the "Apple could not verify" warning.
The xattr command removes that flag.

TimeZoner is signed (ad-hoc) but not "notarized" by Apple — that
costs $99/year and this app is free. The source is open:

    https://github.com/nembal/Timezoner

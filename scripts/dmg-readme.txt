Manual DMG Install
==================

Recommended Homebrew source build
---------------------------------

    brew tap nembal/timezoner https://github.com/nembal/Timezoner
    brew install timezoner
    timezoner-install-app
    timezoner

The DMG is a manual fallback for people who prefer dragging the app
into Applications. TimeZoner is ad-hoc signed but not Apple-notarized,
so macOS may ask you to confirm trust before first launch.

Manual DMG steps
----------------

1. Drag TimeZoner.app onto the Applications folder.

2. Launch TimeZoner from Applications or Spotlight.

3. If macOS asks, right-click TimeZoner.app and choose Open.


If macOS still blocks launch
----------------------------

Open Terminal and paste this command:

    xattr -cr /Applications/TimeZoner.app

If you put the app somewhere other than /Applications, change the path
for that location, for example ~/Applications/TimeZoner.app.

The source is open:

    https://github.com/nembal/Timezoner

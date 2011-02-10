MPDTie Documentation
====================

Description
-----------

MPDTie is a Ruby module to link together the excllent [Bowtie](http://bowtieapp.com/) remote control for OS X and [MPD, the Unix Music Player Daemon](http://mpd.wikia.com/wiki/). It allows you to control MPD from Bowtie and view current track info.

It also contains rbowtie, which is a small library for communication with Bowtie.

Dependencies
------------

Ruby (tested on 1.9, should work fine on 1.8 too)

Required Ruby modules are pecified in the Gemfile - use
> $ bundle install
to install them.

MPDTie relies on libdnssd, which is installed by default on OS X. On Linux, you'll need to install the avahi compatibility layer (the Ubuntu/Debian magic words are: apt-get install libavahi-compat-libdnssd-dev). More information in the [ruby dnssd docs](http://dnssd.rubyforge.org/dnssd/).

Usage
-----

To pair:

> $ ./mpdtie-pair

And add the device in Bowtie's "Remote" tab.

To connect

> $ ./mpdtie


Bugs
----

* Starring doesn't work
* Client isn't very stable (it's a 0.1 release after all)

License
-------

Everything here is released under [CC-BY 3.0](http://creativecommons.org/licenses/by/3.0)

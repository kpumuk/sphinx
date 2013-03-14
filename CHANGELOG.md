## 2.1.1.3712 (Mar 15, 2013)

Bugixes:

  - Fixed broken ranking in Ruby 1.8.7.

## 2.1.1.3711 (Mar 15, 2013)

Features:

  - Updated API to the latest Sphinx version 2.1.1.
  - Refactored specs so they don't require running Sphinx instance and php.

## 0.9.10.2122 (Dec 04, 2009)

Features:

  - Sphinx::Client#escape_string method added.

Bugfixes:

  - Allow empty array or single integer in #set_filter as values.

## 0.9.10.2094 (Nov 23, 2009)

Features:

  - Added logging.
  - Added ability to pass a block to Client#query method to set request parameters.
  - Use CRC32 of the request to select the server.
  - Results returned in an instance of HashWithIndifferentAccess.

## 0.9.10.2091 (Nov 20, 2009)

Features:

  - Added Ruby-style named methods in addition to native Sphinx API naming.
  - Return `Sphinx::Client` object itself from any `set_` method to allow chaining.
  - Status() API call queries all configured servers.

## 0.9.10.2086 (Nov 19, 2009)

Bugfixes:

  - Better documentation.
  - Fixed incomplete reply handling.
  - Sphinx IANA assigned ports are 9312 and 9306 respectively (goodbye, trusty 3312)

## 0.9.10.2043 (Nov 16, 2009)

Features:

  - Updated Sphinx API to version 0.9.10.
  - Added ability to set multiple servers.

Bugfixes:

  - Better argument validation.
  - Properly handle connection timeouts.
  - Added request timeout handling and retries.
  - Close TCP socket on connection failure.

## 0.5.0.1112 (Aug 4, 2008)

Features:

  - Updated Sphinx API to version 0.9.9.

Bugfixes:

  - Fixed support of 64-bit values.

## 0.4.0.1112 (May 2, 2008)

Features:

  - Initial implementation of Sphinx API for Sphinx 0.9.8.

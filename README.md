google-fusion-tables-backup
===========================

Ruby script for backing up your Google Fusion Tables data to CSV.

Usage:

Copy `.secrets.yml.example` to `.secrets.yml` and put in the credentials for the Google account and API key you wish to use. You can obtain an API key using [the Google API console](https://code.google.com/apis/console/): create a project, enable the Fusion Tables API for it, then generate a public API access key. Additionally, if the Google account you wish to access has two-factor authentication enabled, use [an app-specific password](https://security.google.com/settings/security/apppasswords).

By default, the script will download all Fusion Tables associated with an account, taking an optional backup directory path (defaults to `backups`):

    bundle exec ./google-fusion-tables-backup [backup_directory_path]

You can also pass the script the table ID of a specific Fusion Table you'd like to back up:

    bundle exec ./google-fusion-tables-backup backup_directory_path table_id

I would suggest putting this in a cron job, and optionally putting your backup directory under version control.

LICENSE
-------

Copyright (c) 2014 Ryan Baumann

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
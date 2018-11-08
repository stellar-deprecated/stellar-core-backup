# StellarCoreBackup

This application is a basic backup/restore library which creates offline/cold backups and pushes them to S3. Backups can be restored automatically but a pre-restore manual removal of bucket data is required as it doesn't try and overwrite the stellar buckets directory.

All options are configurable in a config file passed in with the `--config` argument.

## Assumptions about environment

At present `stellar-core-backup` makes a few assumptions about the environment that you should be aware of, it expects stellar-core to be installed using the official Debian binary packages available at https://github.com/stellar/packages.  In the event that your own environment differs from the below assumptions, `stellar-core-backup` will definitely break.

## Configuration

| config param | description |
|--------------|-------------|
|working_dir| Path to working directory which will hold temporary files, needs sufficient space to store and untar 1 backup|
|core_config| Path to stellar-core configuration file of the node we are backing up, retrieves database credentials, etc.|
|backup_dir| Path to directory which will hold the final backup|
|s3_bucket| S3 bucket to store/retrieve buckets to/from|
|s3_path| S3 Path prefix, can be used for backing up multiple core nodes to the same bucket|

## Usage As Command Line Tool

##### backup

```
stellar-core-backup --config /etc/stellar/stellar-core-backup.conf --backup
```

##### restore latest backup

```
# manual removal of bucket data
rm -r /var/lib/stellar/buckets/*
stellar-core-backup --config /etc/stellar/stellar-core-backup.conf --restore
```

## Usage as a Library

```ruby
require 'stellar-core-backup'

if options[:backup] then
  scb = StellarCoreBackup::Job.new(
    :config => '/etc/stellar/stellar-core-backup.conf',
    :type   => 'backup'
  )
  scb.run()
elsif options[:restore]
  scb = StellarCoreBackup::Job.new(
    :config => '/etc/stellar/stellar-core-backup.conf',
    :type   => 'restore'
  )
  scb.run()
end
```

## Contributing

1. Fork it ( https://github.com/[my-github-username]/stellar-core-backup/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

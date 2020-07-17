# StellarCoreBackup

This application is a simple backup/restore library which creates offline/cold backups and pushes them to S3. Backups can be restored automatically but the bucket data directory needs to be emptied first as stellar-core-backup doesn't overwrite existing data. This clean out can be done manually or by using the `--clean` option with `--restore`.

All options are configurable in a config file passed in with the `--config` argument.

## Assumptions about environment

At present `stellar-core-backup` makes a few assumptions about the environment and it expects stellar-core to be installed using the official Debian binary packages available at [https://github.com/stellar/packages](). In the event that your own environment differs from this, `stellar-core-backup` will likely break.

AWS credentials can be exported as environment variables or permissions can be granted by an IAM instance role.

## GPG Backup Signing and Verification

To ensure archive consistency and integrity `stellar-core-backup` can use GPG signing and verification. This is enabled by default but can be disabled using the `--no-verify` argument.

The GPG key needs to be installed first which can be done using the `--getkey` command.

We are using SKS Keyservers for public key distribution available at hkp://pool.sks-keyservers.net.

## Configuration

| config param | description |
|--------------|-------------|
|working_dir| Path to working directory which will hold temporary files, needs sufficient space to store and untar 1 backup|
|core_config| Path to stellar-core configuration file of the node we are backing up, retrieves database credentials, etc.|
|backup_dir| Path to directory which will hold the final backup|
|s3_region| S3 region|
|s3_bucket| S3 bucket to store/retrieve buckets to/from|
|s3_path| S3 Path prefix, can be used for backing up multiple core nodes to the same bucket|
|gpg_key| GPG key ID used for signing and verification of the stellar-core backups. The provided ID is the Stellar public key|
|pushgateway_url| Optional prometheus pushgateway URL to publish metrics to|

## Usage As Command Line Tool

##### install public GPG key

```
stellar-core-backup --config /etc/stellar/stellar-core-backup.conf --getkey
```

##### backup data, create SHA256SUMS file, GPG sign it and push to S3

```
stellar-core-backup --config /etc/stellar/stellar-core-backup.conf --backup
```

##### restore latest backup from S3 with auto-clean

```
stellar-core-backup --config /etc/stellar/stellar-core-backup.conf --restore --clean
```

##### list arbitrary number of backups in S3 bucket

```
stellar-core-backup --config /etc/stellar/stellar-core-backup.conf --list [num]
```

##### restore from selected backup file with auto-clean

```
stellar-core-backup --config /etc/stellar/stellar-core-backup.conf --restore --clean --select [bucket-prefix/core-backup-name]
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


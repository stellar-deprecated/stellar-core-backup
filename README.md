# StellarCoreBackup

This application is a simple backup/restore library which creates offline/cold backups and pushes them to S3. Backups can be restored automatically but a pre-restore manual removal of bucket data is required as stellar-core-backup doesn't overwrite the stellar buckets directory.

All options are configurable in a config file passed in with the `--config` argument.

## Assumptions about environment

At present `stellar-core-backup` makes a few assumptions about the environment that you should be aware of, it expects stellar-core to be installed using the official Debian binary packages available at https://github.com/stellar/packages.  In the event that your own environment differs from the above assumptions, `stellar-core-backup` will likely break.

AWS credentials can be exported as environment variables or permissions can be granted by an IAM instance role.

## GPG Backup Signing and Verification

GPG verificaiton is enabled by default. Unless the user disables this securtiy feature with the --no-verify option, GPG signing and verification checks will be run.

The appropriate GPG signing keys need to be in place and the key_id selection is configured in the configuration file.

To install the public Stellar backup key for verification of Stellar provided backups, used the --getkey flag and the provided key-ID contained in the config/sample.yaml file. Change this value for your own key.

`stellar-core-backup --getkey`

The keyservers used to serve this key from belong to the SKS Keyserver service cluster hkp://pool.sks-keyservers.net. 

If you try to verify a backup that has not been signed, you will generate an error.

`gpg: can't open 'SHA256SUMS.sig': No such file or directory`.

## Configuration

| config param | description |
|--------------|-------------|
|working_dir| Path to working directory which will hold temporary files, needs sufficient space to store and untar 1 backup|
|core_config| Path to stellar-core configuration file of the node we are backing up, retrieves database credentials, etc.|
|s3_bucket| S3 bucket to store/retrieve buckets to/from|
|s3_path| S3 Path prefix, can be used for backing up multiple core nodes to the same bucket|
|gpg_key| GPG key ID used for signing and verification of the stellar-core backups. The provided ID is the Stellar signing key|

## Usage As Command Line Tool

##### backup and shasum the backup files then gpg sign the resulting SHA256SUMS file

```
stellar-core-backup --config /etc/stellar/stellar-core-backup.conf --backup
```

##### restore latest backup

```
# Use --clean to remove redundant bucket data
stellar-core-backup --config /etc/stellar/stellar-core-backup.conf --restore --clean
```

##### restore latest backup without gpg verification

```
# Use --clean to remove redundant bucket data
stellar-core-backup --config /etc/stellar/stellar-core-backup.conf --restore --clean --no-verify
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

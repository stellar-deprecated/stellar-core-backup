# StellarCoreBackup

This application is a simple backup/restore library which creates offline/cold backups and pushes them to S3. Backups can be restored automatically but a pre-restore manual removal of bucket data is required as stellar-core-backup doesn't overwrite the stellar buckets directory.

All options are configurable in a config file passed in with the `--config` argument.

## Assumptions about environment

At present `stellar-core-backup` makes a few assumptions about the environment that you should be aware of, it expects stellar-core to be installed using the official Debian binary packages available at https://github.com/stellar/packages.  In the event that your own environment differs from the above assumptions, `stellar-core-backup` will likely break.

AWS credentials can be exported as environment variables or permissions can be granted by an IAM instance role.

## GPG Backup Signing and Verification

Unless the user disables GPG signing and verification using the --no-verify flag, then the gpg checks will be run. The key details are loaded into the config file.

In order for automated gpg signing to work, there needs to be a ~/.gnupg/gpg-agent file with a configuration option allowing pinentry-loopback

```
$ cat ~/.gnupg/gpg-agent.conf
allow-loopback-pinentry
```

It is safest to then restart the gpg-agent if one is running for this config item to take effect.

The appropriate GPG signing keys also need to be in place. The public Stellar Backup key is available from here -

* Add key location!

If you try to verify a backup that has not been signed, you will generate an error

`gpg: can't open 'SHA256SUMS.sig': No such file or directory` 

## Configuration

| config param | description |
|--------------|-------------|
|working_dir| Path to working directory which will hold temporary files, needs sufficient space to store and untar 1 backup|
|core_config| Path to stellar-core configuration file of the node we are backing up, retrieves database credentials, etc.|
|backup_dir| Path to directory which will hold the final backup|
|s3_bucket| S3 bucket to store/retrieve buckets to/from|
|s3_path| S3 Path prefix, can be used for backing up multiple core nodes to the same bucket|
|verifying_gpg_key| If you wish to verify the Stellar provided backups, leave this as backtups@stellar.org|
|signing_gpg_key| This option is only used when signing your own backups, Stellar signs our backups with backups@stellar.org|
|signing_gpg_pass| 'Your GPG Key Passphrase For Your Signing GPG Key!'|

## Usage As Command Line Tool

##### backup but don't shasum the backup files or gpg sing the SHA256SUMS file

```
stellar-core-backup --config /etc/stellar/stellar-core-backup.conf --backup --no-verify
```

##### restore latest backup, gpg verify active by default

```
# Use --clean to removal redundant bucket data
stellar-core-backup --config /etc/stellar/stellar-core-backup.conf --restore --clean
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

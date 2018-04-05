# StellarCoreBackup

Create an offline backup of stellar-core buckets and a corresponding backup of the PostgreSQL database. Push both to a S3 bucket.

Restore a stellar-core node, retrieving latest pushed backup from S3.

Options are configurable in a config file passed in with the `--config` argument.

## Assumptions about environment

At present `stellar-core-backup` makes a few assumptions about the environment it runs in that you should be aware.  In the event that your own environment differs from the below assumptions, `stellar-core-backup` will definitely break.

## Usage As Command Line Tool

##### backup

```
stellar-core-backup --config /etc/stellar/stellar-core-backup.conf --backup
```

##### restore latest backup

```
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

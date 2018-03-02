module StellarCoreBackup
  class Job

    class NoConfig < StandardError ; end

    def initialize(**args)
      if args.has_key?(:config)
        @config       = StellarCoreBackup::Config.new(args[:config])
      else
        puts "info: no config provided"
        raise NoConfig
      end

      if args.has_key?(:type)
        case args[:type]
          when 'backup'
            puts 'info: backing up stellar-core'
            @working_dir  = StellarCoreBackup::Utils.create_working_dir(@config.get('working_dir'))
            @backup_dir   = StellarCoreBackup::Utils.create_backup_dir(@config.get('backup_dir'))
            @cmd          = StellarCoreBackup::Cmd.new(@working_dir)
            @db           = StellarCoreBackup::Database.new(@config)
            @fs           = StellarCoreBackup::Filesystem.new(@config)
            @s3           = StellarCoreBackup::S3.new(@config)
            @job_type     = args[:type]
          when 'restore'
            puts 'info: restoring stellar-core'
            @working_dir  = StellarCoreBackup::Utils.create_working_dir(@config.get('working_dir'))
            @cmd          = StellarCoreBackup::Cmd.new(@working_dir)
            @db_restore   = StellarCoreBackup::Restore::Database.new(@config)
            @fs_restore   = StellarCoreBackup::Restore::Filesystem.new(@config)
            @s3           = StellarCoreBackup::S3.new(@config)
            @utils        = StellarCoreBackup::Utils.new(@config)
            @job_type     = args[:type]
        end
      end
    end

    def run()
      case @job_type
        when 'backup'
          begin
            puts 'info: stopping stellar-core'
            # using sudo, if running as non root uid then you will need to configure sudoers
            stop_core = @cmd.run_and_capture('sudo', ['/bin/systemctl', 'stop', 'stellar-core'])
            # only proceed if core is stopped
            if stop_core.success then
              @db.backup
              @fs.backup
              # create tar archive with both fs and db backups
              @backup = StellarCoreBackup::Utils.create_backup_tar(@working_dir, @backup_dir)
              @s3.push(@backup)
            else
              puts 'error: can not stop stellar-core'
              raise StandardError
            end

            # restart stellar-core post backup
            puts 'info: starting stellar-core'
            # using sudo, if running as non root uid then you will need to configure sudoers
            start_core = @cmd.run_and_capture('sudo', ['/bin/systemctl', 'start', 'stellar-core'])
            if start_core.success then
              puts "info: stellar-core started"
            else
              puts 'error: can not start stellar-core'
              raise StandardError
            end

            # clean up working_dir
            StellarCoreBackup::Utils.cleanup(@working_dir)
          rescue => e
            puts e
            # clean up working_dir
            StellarCoreBackup::Utils.cleanup(@working_dir)
            # TODO:
            # attempt to clear up after ourselves
            # remove working_dir
            # restart stellar-core
          end
        when 'restore'
          begin
            # using sudo, if running as non root uid then you will need to configure sudoers
            stop_core = @cmd.run_and_capture('sudo', ['/bin/systemctl', 'stop', 'stellar-core'])
            # only proceed if core is stopped and FS is clean
            if stop_core.success then
              @backup_archive = @s3.get(@s3.latest)
              if @fs_restore.core_data_dir_empty?() then
                # proceed
                @utils.restore(@backup_archive)
              end
            else
              puts 'error: can not stop stellar-core'
              raise StandardError
            end

            # clean up working_dir
            StellarCoreBackup::Utils.cleanup(@working_dir)
          rescue => e
            puts e
            # clean up working_dir
            StellarCoreBackup::Utils.cleanup(@working_dir)
            # TODO:
            # attempt to clear up after ourselves
            # remove working_dir
            # restart stellar-core
          end
      end
    end

  end
end

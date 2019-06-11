module StellarCoreBackup
  class Job

    class NoConfig < StandardError ; end

    def initialize(**args)
      if args.has_key?(:config) then
        @config       = StellarCoreBackup::Config.new(args[:config])
      else
        puts "info: no config provided"
        raise NoConfig
      end

      @verify = args[:verify] if args.has_key?(:verify)
      @clean  = args[:clean] if args.has_key?(:clean)

      if args.has_key?(:type) then
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
              if @verify then
                create_hash_file = @cmd.run_and_capture('find', ['.', '-type', 'f', '!', '-name', 'SHA256SUMS|', 'xargs', 'sha256sum', '>', 'SHA256SUMS'])
                if create_hash_file.success then
                  puts "info: sha sums file created"
                else
                  puts 'error: error creating sha sums file'
                  raise StandardError
                end
                sign_hash_file = @cmd.run_and_capture('gpg', ['--detach-sign', 'SHA256SUMS'])
                if sign_hash_file.success then
                  puts "info: gpg signature created ok"
                else
                  puts 'error: error signing sha256sum file'
                  raise StandardError
                end
              end
              # create tar archive with fs, db backup files and if requested the file of shas256sums and corresponding gpg signature.
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
          end
        when 'restore'
          begin
            # using sudo, if running as non root uid then you will need to configure sudoers
            stop_core = @cmd.run_and_capture('sudo', ['/bin/systemctl', 'stop', 'stellar-core'])
            # only proceed if core is stopped and FS is clean
            if stop_core.success then
              if @clean then
                 StellarCoreBackup::Utils.cleanbucket(@fs_restore.core_data_dir)
              end
              if @fs_restore.core_data_dir_empty?() then
                @backup_archive = @s3.get(@s3.latest)
                @utils.extract_backup(@backup_archive)
                if @verify then
                  verify_hash_file = @cmd.run_and_capture('gpg', ['--verify', 'SHA256SUMS.sig', 'SHA256SUMS'])
                  if verify_hash_file.success then
                    puts "info: gpg signature processed ok"
                  else
                    puts 'error: error verifying gpg signature'
                    raise StandardError
                  end
                  verify_sha_file_content = @cmd.run_and_capture('sha256sum', ['--status', '--strict', '-c', 'SHA256SUMS'])
                  if verify_sha_file_content.success then
                    puts "info: sha file sums match"
                  else
                    puts 'error: error processing sha256sum file'
                    raise StandardError
                  end
                end
                @fs_restore.restore(@backup_archive)
                @db_restore.restore()

                # restart stellar-core post restore
                puts 'info: starting stellar-core'
                # using sudo, if running as non root uid then you will need to configure sudoers
                start_core = @cmd.run_and_capture('sudo', ['/bin/systemctl', 'start', 'stellar-core'])
                if start_core.success then
                  puts "info: stellar-core started"
                else
                  puts 'error: can not start stellar-core'
                  raise StandardError
                end
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
          end
      end
    end

  end
end

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

      # Set run time options
      @verify   = args[:verify] if args.has_key?(:verify)
      @clean    = args[:clean] if args.has_key?(:clean)
      @listlen  = args[:listlen]

      # Set common run time parameters
      @job_type        = args[:type]
      @gpg_key         = @config.get('gpg_key')
      @working_dir     = StellarCoreBackup::Utils.create_working_dir(@config.get('working_dir'))
      @cmd             = StellarCoreBackup::Cmd.new(@working_dir)
      @select          = args[:select] if args.has_key?(:select)
      @s3              = StellarCoreBackup::S3.new(@config)
      @pushgateway_url = @config.get('pushgateway_url')

      # Set per operation type run time parameters
      if args.has_key?(:type) then
        case args[:type]
          when 'backup'
            puts 'info: backing up stellar-core'
            StellarCoreBackup::Utils.push_metric(@pushgateway_url, 'backup_start_time')
            @backup_dir   = StellarCoreBackup::Utils.create_backup_dir(@config.get('backup_dir'))
            @db           = StellarCoreBackup::Database.new(@config)
            @fs           = StellarCoreBackup::Filesystem.new(@config)
          when 'restore'
            puts 'info: restoring stellar-core'
            StellarCoreBackup::Utils.push_metric(@pushgateway_url, 'restore_start_time')
            @db_restore   = StellarCoreBackup::Restore::Database.new(@config)
            @fs_restore   = StellarCoreBackup::Restore::Filesystem.new(@config)
            @utils        = StellarCoreBackup::Utils.new(@config)
          when 'getkey'
            puts 'info: confirming public gpg key with key server'
          when 'list'
            puts "info: listing last #{@listlen} stellar-core backups"
        end
      end
    end

    def run()
      case @job_type
        when 'getkey'
          begin
            getkey = @cmd.run_and_capture('gpg', ['--keyserver', 'hkp://ipv4.pool.sks-keyservers.net', '--recv-key', @gpg_key, '2>&1'])
            puts 'info: public gpg key installed'
            if ! getkey.success then
              puts "error: failed to get gpg key"
              # dump the gpg output here for user level trouble shooting
              puts "#{getkey.out}"
              raise StandardError
            end
          rescue => e
            puts e
          end
        when 'list'
          begin
            list=@s3.latest(@listlen)
            puts "info: only #{list.length} backup files in bucket" if list.length < @listlen
            puts list
          rescue => e
            puts e
          end
        when 'backup'
          begin
            if !StellarCoreBackup::Utils.core_healthy?(@config) then
                puts "error: Can't back up unhealthy stellar-core"
                raise StandardError
            end
            puts 'info: stopping stellar-core'
            # using sudo, if running as non root uid then you will need to configure sudoers
            stop_core = @cmd.run_and_capture('sudo', ['/bin/systemctl', 'stop', 'stellar-core'])
            # only proceed if core is stopped
            if stop_core.success then
              StellarCoreBackup::Utils.push_metric(@pushgateway_url, 'backup_db_dump_start_time')
              @db.backup
              StellarCoreBackup::Utils.push_metric(@pushgateway_url, 'backup_db_dump_finish_time')
              StellarCoreBackup::Utils.push_metric(@pushgateway_url, 'backup_fs_backup_start_time')
              @fs.backup
              StellarCoreBackup::Utils.push_metric(@pushgateway_url, 'backup_fs_backup_finish_time')
              if @verify then
                StellarCoreBackup::Utils.push_metric(@pushgateway_url, 'backup_verify_start_time')
                create_hash_file = @cmd.run_and_capture('find', ['.', '-type', 'f', '!', '-name', 'SHA256SUMS', '|', 'xargs', 'sha256sum', '>', 'SHA256SUMS'])
                if create_hash_file.success then
                  puts "info: sha sums file created"
                else
                  puts 'error: error creating sha sums file'
                  raise StandardError
                end
                sign_hash_file = @cmd.run_and_capture('gpg', ['--local-user', @gpg_key, '--detach-sign', 'SHA256SUMS'])
                if sign_hash_file.success then
                  puts "info: gpg signature created ok"
                  StellarCoreBackup::Utils.push_metric(@pushgateway_url, 'backup_verify_finish_time')
                else
                  puts 'error: error signing sha256sum file'
                  raise StandardError
                end
              end
              # create tar archive with fs, db backup files and if requested the file of shas256sums and corresponding gpg signature.
              StellarCoreBackup::Utils.push_metric(@pushgateway_url, 'backup_tar_start_time')
              @backup = StellarCoreBackup::Utils.create_backup_tar(@working_dir, @backup_dir)
              StellarCoreBackup::Utils.push_metric(@pushgateway_url, 'backup_tar_finish_time')
              StellarCoreBackup::Utils.push_metric(@pushgateway_url, 'backup_s3_push_start_time')
              @s3.push(@backup)
              StellarCoreBackup::Utils.push_metric(@pushgateway_url, 'backup_s3_push_finish_time')
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
            StellarCoreBackup::Utils.push_metric(@pushgateway_url, 'backup_fail_time')
          else
            StellarCoreBackup::Utils.push_metric(@pushgateway_url, 'backup_success_time')
          end
        when 'restore'
          begin
            # confirm the bucket directory is set to be cleaned or is empty
            # the fs_restore.core_data_dir_empty? throws an exception if it's not empty
            if ! @clean then
              @fs_restore.core_data_dir_empty?()
            end
            # using sudo, if running as non root uid then you will need to configure sudoers
            stop_core = @cmd.run_and_capture('sudo', ['/bin/systemctl', 'stop', 'stellar-core'])
            # only proceed if core is stopped
            if stop_core.success then
              # if no manual selection has been made, use the latest as derived from the s3.latest method
              # this method returns an array so set @select to the first and only element
              @select=@s3.latest(1)[0] if ! @select
              StellarCoreBackup::Utils.push_metric(@pushgateway_url, 'restore_s3_get_start_time')
              @backup_archive = @s3.get(@select)
              StellarCoreBackup::Utils.push_metric(@pushgateway_url, 'restore_s3_get_finish_time')
              StellarCoreBackup::Utils.push_metric(@pushgateway_url, 'restore_untar_start_time')
              @utils.extract_backup(@backup_archive)
              StellarCoreBackup::Utils.push_metric(@pushgateway_url, 'restore_untar_finish_time')
              if @verify then
                StellarCoreBackup::Utils.push_metric(@pushgateway_url, 'restore_verify_start_time')
                verify_hash_file = @cmd.run_and_capture('gpg', ['--local-user', @gpg_key, '--verify', 'SHA256SUMS.sig', 'SHA256SUMS', '2>&1'])
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
                if StellarCoreBackup::Utils.confirm_shasums_definitive(@working_dir, @backup_archive) then
                  puts 'info: SHA256SUMS file list matches delivered archive'
                  StellarCoreBackup::Utils.push_metric(@pushgateway_url, 'restore_verify_finish_time')
                else
                  puts 'error: unknown additional file(s) detected in archive'
                  raise StandardError
                end
              end
              StellarCoreBackup::Utils.cleanbucket(@fs_restore.core_data_dir) if @clean
              StellarCoreBackup::Utils.push_metric(@pushgateway_url, 'restore_fs_restore_start_time')
              @fs_restore.restore(@backup_archive)
              StellarCoreBackup::Utils.push_metric(@pushgateway_url, 'restore_fs_restore_finish_time')
              StellarCoreBackup::Utils.push_metric(@pushgateway_url, 'restore_db_restore_start_time')
              @db_restore.restore()
              StellarCoreBackup::Utils.push_metric(@pushgateway_url, 'restore_db_restore_finish_time')

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
            StellarCoreBackup::Utils.push_metric(@pushgateway_url, 'restore_fail_time')
          else
            StellarCoreBackup::Utils.push_metric(@pushgateway_url, 'restore_success_time')
          end
      end
    end

  end
end

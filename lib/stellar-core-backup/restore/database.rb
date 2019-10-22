require 'pg'

module StellarCoreBackup::Restore
  class Database < StellarCoreBackup::Database
    include Contracts

    attr_reader :dbname

    Contract StellarCoreBackup::Config => Contracts::Any
    def initialize(config)
      @config       = config
      @working_dir  = StellarCoreBackup::Utils.create_working_dir(@config.get('working_dir'))
      @dbname       = check_db_connection
      @cmd          = StellarCoreBackup::Cmd.new(@working_dir)
    end

    public
    Contract nil => nil
    def restore()
      puts "info: database restored" if pg_restore()
    end

    private
    Contract nil => Bool
    def pg_restore()
      # we are restoring to public schema
      pg_restore = @cmd.run('pg_restore', ['-n', 'public', '--jobs', "#{StellarCoreBackup::Utils.num_cores?()}", '-c', '-d', @dbname, 'core-db/'])
      if pg_restore.success then
        return true
      else
        return false
      end
    end

  end
end

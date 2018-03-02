require 'pg'

module StellarCoreBackup
  class Database
    include Contracts

    attr_reader :dbname

    Contract StellarCoreBackup::Config => Contracts::Any
    def initialize(config)
      @config       = config
      @working_dir  = StellarCoreBackup::Utils.create_working_dir(@config.get('working_dir'))
      @dbname       = check_db_connection
    end

    public
    def backup()
      pg_dump()
    end

    private
    #Contract nil, StellarCoreBackup::CmdResult
    def pg_dump()
      cmd = StellarCoreBackup::Cmd.new(@working_dir)
      puts "info: connecting (#{get_db_details(@config.get('core_config')).gsub(/password=(.*)/, 'password=********')})"
      pg_dump = cmd.run('pg_dump', ['--dbname', @dbname, '--format', 'd', '--file', "#{@working_dir}/core-db/"])
      if pg_dump.success then
        puts "info: database backup complete"
      end
    end

    private
    # check we have passwordless access to postgres
    Contract nil => Contracts::Any
    def check_db_connection()
      # TODO move to config
      dbname = get_db_details(@config.get('core_config'))
      begin
        conn = PG.connect(dbname)
        conn.exec("SELECT * FROM pg_stat_activity") do |result|
          # 2 => PGRES_TUPLES_OK
          if result.result_status == 2 then
            return dbname
          end
        end
      rescue PG::Error
        puts "error: failed to connect to db"
        exit
      end
    end

    private
    Contract String => String
    def get_db_details(config)
      File.open(config,'r') do |fd|
        fd.each_line do |line|
          if (line[/^DATABASE=/]) then
            # "postgresql://dbname=stellar user=stellar"
            connection_str = /^DATABASE=(.*)/.match(line).captures[0].gsub!(/"postgresql:\/\/(.*)"$/,'\1')
            return connection_str
          end
        end
      end
    end

  end
end

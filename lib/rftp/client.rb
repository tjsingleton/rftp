module RFTP
  Credentials = Struct.new :host, :user, :passwd, :acct
  Log = Logger.new(STDOUT)
  Log.level = Logger::DEBUG

  class Client
    def initialize(host = nil, user = nil, passwd = nil, acct = nil )
      @credentials = Credentials.new host, user, passwd, acct
      @connection = CompositeConnection.new(self)
      yield self if block_given?
    end

    attr_reader :credentials, :connection

    def cp_r(local_path, destination_path = "")
      Log.info "cp_r: #{local_path}, #{destination_path}"
      FileList.new(local_path).each do |path|
        dest = File.join(destination_path, path)
        Log.debug "cp_r: #{path} to #{dest}"
        @connection.enqueue :copy_to, path.shellescape, dest
      end
    end

    def close
      @connection.close
    end
  end

#  * getbinaryfile
#  * putbinaryfile
#  * mkdir
#  * chdir
#  * nlst
#  * size
#  * rename
#  * delete

  class CompositeConnection
    def initialize(client, workers = 5)
      @client = client
      @queue = Queue.new
      @threads = workers.times.map { build_worker }
    end

    attr_reader :queue, :threads

    def enqueue(cmd, *args)
      @queue.push({:method => cmd, :args => args})
    end

    def dequeue
      work = @queue.pop
      Thread.current[:connection].send work[:method], *work[:args]
    rescue Exception => e
      Log.error e
      Log.debug "dequeue: #{work[:method]} - #{work[:args].join(",")}"
    end

    def build_worker
      Thread.new do
        Thread.current[:connection] = build_connection
        loop { dequeue }
      end
    end

    def build_connection
      @session ||= Session.new
      FTP.new(@client.credentials, @session)
    end

    def close
      count = @threads.count
      Log.info "close: #{count} connections"
      count.times { enqueue :close }
      until @queue.empty?; end
    end
  end

  class Session
    def initialize
      @mutex = Mutex.new
      @dirs = []
    end

    def dir?(dir)
      @mutex.synchronize { @dirs.include? dir }
    end

    def add_dir(dir)
      @mutex.synchronize { @dirs << dir }
    end
  end

  class FTP
    def initialize(credentials, session = Session.new)
      @credentials = credentials
      @session = session
      connect
    end

    def connection
      connect if @connection.closed?
      @connection
    end

    def connect
      @connection = Net::FTP.new *@credentials.to_a
      @connection.resume = true
    end

    def close
      @connection.close
      Thread.stop unless Thread.main == Thread.current
    end

    def mkpath(path)
      Log.info "mkpath: #{path}"

      if @session.dir? path
        Log.debug "mkpath: #{path} known to exist"
        return
      else
        @session.add_dir path
      end

      starting_pwd = connection.pwd
      Log.debug "mkpath: starting in #{starting_pwd}"
      return if starting_pwd == path

      if path.start_with? "/" && starting_pwd != "/"
        Log.debug "mkpath: chdir /"
        connection.chdir "/"
      end

      path.split("/").each do |dir|
        next if dir.empty?
        unless connection.nlst.include?(dir)
          Log.debug "mkpath: mkdir #{dir}"
          connection.mkdir(dir)
        end
        Log.debug "mkpath: chdir #{dir}"
        connection.chdir(dir)
      end

      Log.debug "mkpath: done, returning to #{starting_pwd}"
      connection.chdir starting_pwd
    rescue Exception => e
      Log.error e
      Log.debug "mkpath: error, returning to #{starting_pwd} and retrying"
      connection.chdir starting_pwd
    end

    def copy_to(file, path)
      Log.info "copy_to: #{file}, #{path}"
      mkpath File.dirname(path)
      connection.putbinaryfile file, path, 8192
    end
  end
end

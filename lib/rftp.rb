require "net/ftp"
require "logger"
require "shellwords"

require "rubygems"
require "bundler/setup"
require "rake"

require "rftp/version"
require "rftp/client"

module RFTP
  Credentials = Struct.new :host, :user, :passwd, :acct
  Log = Logger.new(STDOUT)
  Log.level = Logger::DEBUG
end
